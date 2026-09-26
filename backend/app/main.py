from __future__ import annotations

import asyncio
from collections import defaultdict, deque
from contextlib import asynccontextmanager
from dataclasses import dataclass
import hashlib
import hmac
import json
import logging
import os
import secrets
import threading
import time
from pathlib import Path
from typing import Any
from urllib.parse import quote

from fastapi import (
    Depends,
    FastAPI,
    File,
    HTTPException,
    Request,
    Response,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from starlette.concurrency import run_in_threadpool

from app.audio import MAX_UPLOAD_BYTES, InvalidAudio, parse_mono_pcm16_wav
from app.assistant import (
    AssistantProviderError,
    AssistantRateLimited,
    AssistantUnavailable,
    assistant_mode,
    generate_answer,
    offline_assistant_available,
    provider_is_configured,
    validate_question,
)
from app.request_limits import MaxRequestBodySize


logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger("baby_monitor.preview")

MODEL_ID = os.getenv(
    "BABY_MONITOR_MODEL_ID", "AmeerHesham/distilhubert-finetuned-baby_cry"
)
MODEL_REVISION = os.getenv(
    "BABY_MONITOR_MODEL_REVISION",
    "7b9a7700ef09ab81ea597cb4bbb87c283536ae2c",
)
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "").strip()
FIREBASE_SERVICE_ACCOUNT_PATH = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "").strip()
FIREBASE_SERVICE_ACCOUNT_JSON = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
BETA_ACCESS_KEY = os.getenv("BETA_ACCESS_KEY", "").strip()
BETA_SESSION_COOKIE = "baby_monitor_beta"
BETA_SESSION_COOKIE_VALUE = (
    hmac.new(
        BETA_ACCESS_KEY.encode("utf-8"),
        b"baby-monitor-private-beta-session-v1",
        hashlib.sha256,
    ).hexdigest()
    if BETA_ACCESS_KEY
    else ""
)
WEB_DIR = os.getenv("BABY_MONITOR_WEB_DIR", "/srv/baby-monitor/web")
DOCTOR_CALL_DEMO_PAGE = Path(__file__).with_name("doctor_call_demo.html").read_text(
    encoding="utf-8"
)

MAX_REQUESTS_PER_USER_PER_HOUR = 20
MAX_REQUESTS_GLOBAL_PER_HOUR = 100
MAX_REQUEST_BODY_BYTES = MAX_UPLOAD_BYTES + 64 * 1024
MAX_ASSISTANT_REQUEST_BODY_BYTES = 64 * 1024

_bearer = HTTPBearer(auto_error=False)
_model: Any | None = None
_processor: Any | None = None
_model_error = False


class AnalysisResponse(BaseModel):
    category: str
    advice: str
    score_percent: int
    urgent: bool = False
    experimental: bool = True


class BetaSessionRequest(BaseModel):
    access_code: str


class AssistantRequest(BaseModel):
    question: str


class AssistantResponse(BaseModel):
    answer: str


@dataclass
class RequestLimit:
    timestamps: deque[float]


@dataclass
class DemoCallPeer:
    websocket: WebSocket
    role: str = ""
    display_name: str = ""
    doctor_level: str = ""
    policy_accepted: bool = False
    available: bool = False
    partner_id: str | None = None
    suspended: bool = False


_limit_lock = threading.Lock()
_user_limits: dict[str, RequestLimit] = defaultdict(lambda: RequestLimit(deque()))
_global_requests: deque[float] = deque()
_demo_call_lock = asyncio.Lock()
_demo_call_peers: dict[str, DemoCallPeer] = {}
_DEMO_DOCTOR_LEVELS = {"أخصائي", "استشاري"}


def _valid_beta_session(value: str | None) -> bool:
    return bool(
        value
        and BETA_SESSION_COOKIE_VALUE
        and secrets.compare_digest(value, BETA_SESSION_COOKIE_VALUE)
    )


def _initialize_model() -> None:
    global _model, _processor, _model_error

    try:
        import torch
        from transformers import AutoFeatureExtractor, AutoModelForAudioClassification

        torch.set_num_threads(max(1, min(4, os.cpu_count() or 1)))
        _processor = AutoFeatureExtractor.from_pretrained(
            MODEL_ID, revision=MODEL_REVISION, trust_remote_code=False
        )
        _model = AutoModelForAudioClassification.from_pretrained(
            MODEL_ID,
            revision=MODEL_REVISION,
            trust_remote_code=False,
            use_safetensors=True,
        )
        _model.to("cpu")
        _model.eval()
        _model_error = False
    except Exception:
        # Do not include user audio or bearer credentials in service logs.
        logger.exception("Experimental model could not be loaded.")
        _model_error = True


@asynccontextmanager
async def lifespan(_: FastAPI):
    await run_in_threadpool(_initialize_model)
    yield


app = FastAPI(
    title="Baby Monitor Experimental Cry Analysis",
    version="0.1.0",
    description=(
        "Closed-preview inference only. Results are experimental and are not a diagnosis."
    ),
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
    lifespan=lifespan,
)
app.add_middleware(MaxRequestBodySize, max_bytes=MAX_REQUEST_BODY_BYTES)
app.add_middleware(
    MaxRequestBodySize,
    max_bytes=MAX_ASSISTANT_REQUEST_BODY_BYTES,
    paths={"/v1/newborn-assistant"},
)


@app.middleware("http")
async def protect_private_web_app(request: Request, call_next):
    path = request.url.path
    is_private_app = path == "/app" or path.startswith("/app/")
    is_doctor_call_demo = path == "/call-demo"
    if is_private_app or is_doctor_call_demo:
        if not _valid_beta_session(request.cookies.get(BETA_SESSION_COOKIE)):
            next_path = request.url.path
            if request.url.query:
                next_path += "?" + request.url.query
            return RedirectResponse(
                url="/?next=" + quote(next_path, safe="/?=&"),
                status_code=303,
            )
    return await call_next(request)


if os.path.isdir(WEB_DIR):
    app.mount(
        "/app",
        StaticFiles(directory=WEB_DIR, html=True),
        name="private_baby_monitor_web",
    )


def _firebase_app():
    if not FIREBASE_PROJECT_ID:
        raise HTTPException(status_code=503, detail="Authentication is not configured.")

    import firebase_admin
    from firebase_admin import credentials

    try:
        return firebase_admin.get_app()
    except ValueError:
        pass

    if FIREBASE_SERVICE_ACCOUNT_PATH:
        credential = credentials.Certificate(FIREBASE_SERVICE_ACCOUNT_PATH)
    elif FIREBASE_SERVICE_ACCOUNT_JSON:
        try:
            credential = credentials.Certificate(json.loads(FIREBASE_SERVICE_ACCOUNT_JSON))
        except (json.JSONDecodeError, ValueError, TypeError) as error:
            logger.error("Firebase Admin secret is not valid JSON credentials.")
            raise HTTPException(
                status_code=503, detail="Authentication is not configured."
            ) from error
    else:
        credential = credentials.ApplicationDefault()

    try:
        return firebase_admin.initialize_app(
            credential, {"projectId": FIREBASE_PROJECT_ID}
        )
    except ValueError:
        return firebase_admin.get_app()


async def authenticated_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str:
    if _valid_beta_session(request.cookies.get(BETA_SESSION_COOKIE)):
        return "private-beta"

    if (
        BETA_ACCESS_KEY
        and credentials is not None
        and credentials.scheme.lower() == "bearer"
        and secrets.compare_digest(credentials.credentials, BETA_ACCESS_KEY)
    ):
        return "private-beta"

    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Sign-in is required.")

    try:
        from firebase_admin import auth

        firebase_app = await run_in_threadpool(_firebase_app)
        claims = await run_in_threadpool(
            auth.verify_id_token, credentials.credentials, app=firebase_app
        )
    except HTTPException:
        raise
    except Exception as error:
        logger.info("Preview authentication rejected (%s).", type(error).__name__)
        raise HTTPException(
            status_code=401, detail="Sign-in token is invalid or expired."
        ) from error

    if claims.get("aud") != FIREBASE_PROJECT_ID or claims.get("iss") != (
        f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}"
    ):
        raise HTTPException(status_code=401, detail="Sign-in token is invalid.")
    uid = claims.get("uid")
    if not isinstance(uid, str) or not uid:
        raise HTTPException(status_code=401, detail="Sign-in token is invalid.")
    return uid


def _consume_rate_limit(uid: str) -> None:
    now = time.monotonic()
    cutoff = now - 60 * 60
    with _limit_lock:
        while _global_requests and _global_requests[0] <= cutoff:
            _global_requests.popleft()

        for stale_uid in tuple(_user_limits):
            stale_bucket = _user_limits[stale_uid].timestamps
            while stale_bucket and stale_bucket[0] <= cutoff:
                stale_bucket.popleft()
            if not stale_bucket:
                del _user_limits[stale_uid]

        user_bucket = _user_limits[uid].timestamps
        while user_bucket and user_bucket[0] <= cutoff:
            user_bucket.popleft()

        if len(user_bucket) >= MAX_REQUESTS_PER_USER_PER_HOUR:
            raise HTTPException(status_code=429, detail="Preview request limit reached.")
        if len(_global_requests) >= MAX_REQUESTS_GLOBAL_PER_HOUR:
            raise HTTPException(status_code=429, detail="Preview is temporarily busy.")

        user_bucket.append(now)
        _global_requests.append(now)


def _classify(frames: bytes) -> tuple[str, int]:
    if _model is None or _processor is None:
        raise HTTPException(status_code=503, detail="Experimental model is unavailable.")

    import numpy as np
    import torch

    samples = np.frombuffer(frames, dtype="<i2").astype(np.float32) / 32768.0
    inputs = _processor(samples, sampling_rate=16_000, return_tensors="pt")
    with torch.inference_mode():
        logits = _model(**inputs).logits
        probabilities = torch.softmax(logits[0], dim=-1)
        predicted_id = int(torch.argmax(probabilities).item())
        top_score = float(probabilities[predicted_id].item())

    labels = _model.config.id2label
    label = labels.get(predicted_id, labels.get(str(predicted_id), ""))
    normalized = str(label).strip().lower().replace(" ", "_").replace("-", "_")
    categories = {
        "hungry": "hungry",
        "belly_pain": "belly_pain",
        "burping": "burping",
        "discomfort": "discomfort",
        "tired": "tiredness",
        "tiredness": "tiredness",
    }
    category = categories.get(normalized)
    score_percent = min(100, max(0, round(top_score * 100))) if category else 0
    return category or "unclear", score_percent


_PRIVATE_BETA_LOGIN_PAGE = "<!doctype html>\n<html lang=\"ar\" dir=\"rtl\">\n<head>\n  <meta charset=\"utf-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n  <meta name=\"theme-color\" content=\"#fdfbff\">\n  <title>Baby Monitor • النسخة الخاصة</title>\n  <style>\n    :root { color-scheme: light; font-family: system-ui, -apple-system, sans-serif; }\n    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #fdfbff; color: #25202a; }\n    main { box-sizing: border-box; width: min(92vw, 420px); padding: 28px; border-radius: 24px; background: white; box-shadow: 0 10px 35px #34213916; }\n    h1 { margin: 0 0 8px; font-size: 1.6rem; }\n    p { line-height: 1.7; color: #625968; }\n    label { display: block; margin: 20px 0 8px; font-weight: 600; }\n    input, button { box-sizing: border-box; width: 100%; min-height: 50px; border-radius: 14px; font: inherit; }\n    input { border: 1px solid #aaa1ae; padding: 12px; direction: ltr; text-align: center; }\n    button { margin-top: 14px; border: 0; background: #9c3970; color: white; font-weight: 700; }\n    #status { min-height: 24px; }\n  </style>\n</head>\n<body>\n  <main>\n    <h1>Baby Monitor</h1>\n    <p>نسخة تجريبية خاصة للاستخدام على هاتفك. أدخلي رمز الدخول الذي وصلك لفتح التطبيق.</p>\n    <form id=\"login\">\n      <label for=\"code\">رمز دخول النسخة التجريبية</label>\n      <input id=\"code\" type=\"password\" autocomplete=\"current-password\" required maxlength=\"128\">\n      <button id=\"submit\" type=\"submit\">فتح التطبيق</button>\n    </form>\n    <p id=\"status\" role=\"status\" aria-live=\"polite\"></p>\n  </main>\n  <script>\n    const form = document.getElementById('login');\n    const input = document.getElementById('code');\n    const status = document.getElementById('status');\n    const button = document.getElementById('submit');\n    form.addEventListener('submit', async (event) => {\n      event.preventDefault();\n      button.disabled = true;\n      status.textContent = 'جارٍ التحقق…';\n      try {\n        const response = await fetch('/v1/session', {\n          method: 'POST',\n          credentials: 'same-origin',\n          headers: { 'Content-Type': 'application/json' },\n          body: JSON.stringify({ access_code: input.value })\n        });\n        if (response.ok) {\n          location.replace('/app/');\n          return;\n        }\n        status.textContent = response.status === 503\n          ? 'خدمة النسخة الخاصة لم تُجهّز بعد.'\n          : response.status === 429\n            ? 'محاولات كثيرة. انتظري قليلًا ثم أعيدي المحاولة.'\n            : 'الرمز غير صحيح. تحققي منه وأعيدي المحاولة.';\n      } catch (_) {\n        status.textContent = 'تعذر الاتصال. تحققي من الإنترنت وحاولي مرة أخرى.';\n      } finally {\n        button.disabled = false;\n      }\n    });\n  </script>\n</body>\n</html>"

_PRIVATE_BETA_LOGIN_PAGE = _PRIVATE_BETA_LOGIN_PAGE.replace(
    "    const button = document.getElementById('submit');\n",
    "    const button = document.getElementById('submit');\n"
    "    const requestedNext = new URLSearchParams(location.search).get('next') || '/app/';\n"
    "    const next = requestedNext.startsWith('/') && !requestedNext.startsWith('//')\n"
    "      ? requestedNext\n"
    "      : '/app/';\n",
).replace(
    "          location.replace('/app/');\n",
    "          location.replace(next);\n",
)

@app.get("/", response_class=HTMLResponse)
def private_beta_login() -> HTMLResponse:
    return HTMLResponse(_PRIVATE_BETA_LOGIN_PAGE)


@app.post("/v1/session")
def create_private_beta_session(
    payload: BetaSessionRequest,
    request: Request,
    response: Response,
) -> dict[str, bool]:
    if not BETA_ACCESS_KEY:
        raise HTTPException(status_code=503, detail="Private beta is not configured.")
    remote = request.client.host if request.client else "unknown"
    _consume_rate_limit("login:" + remote)
    if len(payload.access_code) > 128 or not secrets.compare_digest(
        payload.access_code.strip(), BETA_ACCESS_KEY
    ):
        raise HTTPException(status_code=401, detail="Invalid preview code.")

    response.set_cookie(
        key=BETA_SESSION_COOKIE,
        value=BETA_SESSION_COOKIE_VALUE,
        max_age=12 * 60 * 60,
        secure=True,
        httponly=True,
        samesite="strict",
        path="/",
    )
    return {"ok": True}


@app.get("/call-demo", response_class=HTMLResponse)
def doctor_call_demo() -> HTMLResponse:
    """Serve the free two-device WebRTC demo after beta login."""
    return HTMLResponse(DOCTOR_CALL_DEMO_PAGE)


async def _send_demo_message(peer_id: str, message: dict[str, Any]) -> None:
    peer = _demo_call_peers.get(peer_id)
    if peer is None:
        return
    try:
        await peer.websocket.send_json(message)
    except Exception:
        # Cleanup runs when the WebSocket disconnect is observed.
        return


async def _finish_demo_pair(peer: DemoCallPeer, message: dict[str, Any]) -> None:
    partner_id = peer.partner_id
    peer.partner_id = None
    if peer.role == "doctor":
        peer.available = not peer.suspended
    if partner_id is None:
        return
    partner = _demo_call_peers.get(partner_id)
    if partner is not None:
        partner.partner_id = None
        if partner.role == "doctor":
            partner.available = not partner.suspended
        await _send_demo_message(partner_id, message)


async def _handle_demo_message(client_id: str, message: Any) -> None:
    if not isinstance(message, dict):
        return

    message_type = message.get("type")
    async with _demo_call_lock:
        peer = _demo_call_peers.get(client_id)
        if peer is None:
            return

        if message_type == "register":
            role = message.get("role")
            if role not in {"patient", "doctor"}:
                await _send_demo_message(client_id, {"type": "error", "message": "وضع التجربة غير صالح."})
                return
            peer.role = role
            display_name = message.get("display_name")
            peer.display_name = (
                " ".join(display_name.strip().split())[:60]
                if isinstance(display_name, str) and display_name.strip()
                else ("طبيب تجريبي" if role == "doctor" else "مستخدم التجربة")
            )
            doctor_level = message.get("doctor_level")
            peer.doctor_level = (
                doctor_level.strip()
                if isinstance(doctor_level, str) and doctor_level.strip() in _DEMO_DOCTOR_LEVELS
                else ""
            )
            peer.policy_accepted = bool(message.get("policy_accepted"))
            peer.available = False
            await _send_demo_message(
                client_id,
                {
                    "type": "registered",
                    "client_id": client_id,
                    "role": role,
                    "display_name": peer.display_name,
                },
            )
            return

        if not peer.role:
            await _send_demo_message(client_id, {"type": "error", "message": "سجّلي وضع التجربة أولًا."})
            return

        if message_type == "set_online":
            if peer.role != "doctor":
                await _send_demo_message(client_id, {"type": "error", "message": "هذا الأمر متاح لوضع الطبيب فقط."})
                return
            if peer.suspended:
                await _send_demo_message(client_id, {"type": "error", "message": "تم إيقاف جلسة الطبيب بسبب مخالفة سياسة التواصل."})
                return
            if peer.partner_id is not None:
                await _send_demo_message(client_id, {"type": "error", "message": "أنهي المكالمة الحالية أولًا."})
                return
            display_name = message.get("display_name")
            normalized_name = " ".join(display_name.strip().split()) if isinstance(display_name, str) else ""
            doctor_level = message.get("doctor_level")
            normalized_level = doctor_level.strip() if isinstance(doctor_level, str) else ""
            accepted = bool(message.get("policy_accepted"))
            if message.get("available") is True and (
                len(normalized_name) < 2
                or normalized_level not in _DEMO_DOCTOR_LEVELS
                or not accepted
            ):
                await _send_demo_message(
                    client_id,
                    {"type": "error", "message": "أكملي اسم الطبيب، الصفة، والموافقة على سياسة التواصل قبل الظهور أونلاين."},
                )
                return
            if normalized_name:
                peer.display_name = normalized_name[:60]
            if normalized_level in _DEMO_DOCTOR_LEVELS:
                peer.doctor_level = normalized_level
            peer.policy_accepted = accepted
            peer.available = bool(message.get("available"))
            await _send_demo_message(
                client_id,
                {"type": "online", "available": peer.available, "display_name": peer.display_name},
            )
            return

        if message_type == "find_doctor":
            if peer.role != "patient":
                await _send_demo_message(client_id, {"type": "error", "message": "ابحثي عن الطبيب من وضع المستخدم."})
                return
            if not peer.policy_accepted:
                await _send_demo_message(client_id, {"type": "error", "message": "وافقي على سياسة التواصل قبل البحث عن طبيب."})
                return
            if peer.partner_id is not None:
                await _send_demo_message(client_id, {"type": "error", "message": "لديك طلب أو مكالمة قائمة بالفعل."})
                return
            doctor_id = next(
                (
                    candidate_id
                    for candidate_id, candidate in _demo_call_peers.items()
                    if candidate_id != client_id
                    and candidate.role == "doctor"
                    and candidate.available
                    and not candidate.suspended
                    and candidate.partner_id is None
                ),
                None,
            )
            if doctor_id is None:
                await _send_demo_message(client_id, {"type": "no_doctor"})
                return
            doctor = _demo_call_peers[doctor_id]
            doctor_label = doctor.display_name or "طبيب تجريبي"
            if doctor.doctor_level:
                doctor_label += " — " + doctor.doctor_level
            peer.partner_id = doctor_id
            doctor.partner_id = client_id
            doctor.available = False
            await _send_demo_message(
                client_id,
                {
                    "type": "matched",
                    "partner_id": doctor_id,
                    "display_name": doctor_label,
                },
            )
            await _send_demo_message(
                doctor_id,
                {
                    "type": "matched",
                    "partner_id": client_id,
                    "display_name": "مستخدم التجربة",
                },
            )
            return

        if message_type == "policy_update":
            peer.policy_accepted = bool(message.get("accepted"))
            return

        if message_type == "report_contact_exchange":
            if peer.partner_id is None:
                await _send_demo_message(client_id, {"type": "error", "message": "لا توجد جلسة قائمة للإبلاغ عنها."})
                return
            partner_id = peer.partner_id
            partner = _demo_call_peers.get(partner_id)
            doctor_id = client_id if peer.role == "doctor" else partner_id
            doctor = _demo_call_peers.get(doctor_id)
            if doctor is not None and doctor.role == "doctor":
                doctor.available = False
                doctor.suspended = True
                await _send_demo_message(
                    doctor_id,
                    {"type": "doctor_suspended"},
                )
            await _finish_demo_pair(peer, {"type": "policy_ended"})
            await _send_demo_message(client_id, {"type": "report_received"})
            return

        if message_type in {"accept", "reject"}:
            if peer.role != "doctor" or peer.partner_id is None:
                await _send_demo_message(client_id, {"type": "error", "message": "لا يوجد طلب اتصال قائم."})
                return
            patient_id = peer.partner_id
            if message_type == "reject":
                await _finish_demo_pair(peer, {"type": "rejected"})
                await _send_demo_message(client_id, {"type": "rejected"})
            else:
                await _send_demo_message(patient_id, {"type": "accepted"})
                await _send_demo_message(client_id, {"type": "accepted"})
            return

        if message_type == "signal":
            target_id = peer.partner_id
            data = message.get("data")
            if target_id is None or not isinstance(data, dict):
                return
            await _send_demo_message(
                target_id,
                {"type": "signal", "from": client_id, "data": data},
            )
            return

        if message_type == "hangup":
            await _finish_demo_pair(peer, {"type": "hangup"})
            await _send_demo_message(client_id, {"type": "hangup"})
            return

        await _send_demo_message(client_id, {"type": "error", "message": "أمر التجربة غير معروف."})


@app.websocket("/v1/demo-call/ws")
async def doctor_call_demo_socket(websocket: WebSocket) -> None:
    if not _valid_beta_session(websocket.cookies.get(BETA_SESSION_COOKIE)):
        await websocket.close(code=1008)
        return

    await websocket.accept()
    client_id = secrets.token_urlsafe(9)
    async with _demo_call_lock:
        _demo_call_peers[client_id] = DemoCallPeer(websocket=websocket)
    await _send_demo_message(client_id, {"type": "connected", "client_id": client_id})

    try:
        while True:
            message = await websocket.receive_json()
            await _handle_demo_message(client_id, message)
    except WebSocketDisconnect:
        pass
    except Exception as error:
        logger.info("Doctor-call demo socket ended (%s).", type(error).__name__)
    finally:
        async with _demo_call_lock:
            peer = _demo_call_peers.pop(client_id, None)
            if peer is not None and peer.partner_id is not None:
                partner_id = peer.partner_id
                partner = _demo_call_peers.get(partner_id)
                if partner is not None:
                    partner.partner_id = None
                    if partner.role == "doctor":
                        partner.available = True
                    await _send_demo_message(partner_id, {"type": "hangup"})



ADVICE = {
    "hungry": "قد يكون الجوع ضمن الاحتمالات. راجعي إشارات الرضاعة وموعدها المعتاد.",
    "belly_pain": "النموذج رجّح فئة ألم البطن؛ هذا لا يشخّص المغص. راقبي السياق واستشيري طبيب الطفل عند القلق.",
    "burping": "النموذج رجّح فئة الحاجة للتجشؤ. جرّبي التجشؤ بلطف مع دعم رأس الطفل ورقبته.",
    "discomfort": "النموذج رجّح انزعاجًا عامًا. افحصي الحفاض والملابس وحرارة المكان والضوضاء.",
    "tiredness": "النموذج رجّح التعب أو النعاس. خففي المثيرات وراقبي إشارات النعاس.",
    "unclear": "لم يتعرف النموذج على فئة واضحة. افحصي احتياجات الطفل وسياق البكاء.",
}


@app.get("/v1/health")
def health(response: Response) -> dict[str, bool | str]:
    model_ready = _model is not None and _processor is not None
    if not model_ready:
        response.status_code = 503
    return {
        "status": "ok" if model_ready and not _model_error else "model_unavailable",
        "model_ready": model_ready,
        "assistant_configured": provider_is_configured(),
        "assistant_available": offline_assistant_available(),
        "assistant_mode": assistant_mode(),
    }


@app.post("/v1/newborn-assistant", response_model=AssistantResponse)
async def newborn_assistant(
    payload: AssistantRequest,
    response: Response,
    uid: str = Depends(authenticated_user),
) -> AssistantResponse:
    response.headers["Cache-Control"] = "no-store"
    try:
        question = validate_question(payload.question)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    _consume_rate_limit("assistant:" + uid)

    try:
        answer = await generate_answer(question)
    except AssistantUnavailable as error:
        raise HTTPException(
            status_code=503,
            detail="The newborn assistant is not configured.",
        ) from error
    except AssistantRateLimited as error:
        raise HTTPException(
            status_code=429,
            detail="The newborn assistant is temporarily busy.",
        ) from error
    except AssistantProviderError as error:
        # Do not log the question or model response; both can contain private data.
        logger.warning("Newborn assistant provider failed: %s", type(error).__name__)
        raise HTTPException(
            status_code=503,
            detail="The newborn assistant is temporarily unavailable.",
        ) from error

    return AssistantResponse(answer=answer)


@app.post("/v1/cry-analysis", response_model=AnalysisResponse)
async def analyze_cry(
    response: Response,
    audio: UploadFile = File(...),
    uid: str = Depends(authenticated_user),
) -> AnalysisResponse:
    response.headers["Cache-Control"] = "no-store"
    _consume_rate_limit(uid)

    content_type = (audio.content_type or "").lower().split(";", maxsplit=1)[0]
    if content_type not in {"audio/wav", "audio/x-wav", "application/octet-stream"}:
        raise HTTPException(status_code=415, detail="Upload a WAV audio recording.")

    try:
        data = await audio.read(MAX_UPLOAD_BYTES + 1)
        try:
            frames = parse_mono_pcm16_wav(data)
        except InvalidAudio as error:
            raise HTTPException(status_code=400, detail=str(error)) from error
    finally:
        await audio.close()

    try:
        category, score_percent = await run_in_threadpool(_classify, frames)
        return AnalysisResponse(
            category=category,
            advice=ADVICE[category],
            score_percent=score_percent,
            urgent=False,
            experimental=True,
        )
    except HTTPException:
        raise
    except Exception as error:
        logger.exception("Experimental inference failed; audio was not persisted.")
        raise HTTPException(status_code=503, detail="Analysis could not be completed.") from error
