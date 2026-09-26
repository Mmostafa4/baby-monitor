from __future__ import annotations

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
from typing import Any

from fastapi import Depends, FastAPI, File, HTTPException, Request, Response, UploadFile
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


_limit_lock = threading.Lock()
_user_limits: dict[str, RequestLimit] = defaultdict(lambda: RequestLimit(deque()))
_global_requests: deque[float] = deque()


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
    if path == "/app" or path.startswith("/app/"):
        if not _valid_beta_session(request.cookies.get(BETA_SESSION_COOKIE)):
            return RedirectResponse(url="/", status_code=303)
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
