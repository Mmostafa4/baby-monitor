from __future__ import annotations

from collections import defaultdict, deque
from contextlib import asynccontextmanager
from dataclasses import dataclass
import json
import logging
import os
import threading
import time
from typing import Any

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel
from starlette.concurrency import run_in_threadpool

from app.audio import MAX_UPLOAD_BYTES, InvalidAudio, parse_mono_pcm16_wav
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

MAX_REQUESTS_PER_USER_PER_HOUR = 20
MAX_REQUESTS_GLOBAL_PER_HOUR = 100
MAX_REQUEST_BODY_BYTES = MAX_UPLOAD_BYTES + 64 * 1024

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


@dataclass
class RequestLimit:
    timestamps: deque[float]


_limit_lock = threading.Lock()
_user_limits: dict[str, RequestLimit] = defaultdict(lambda: RequestLimit(deque()))
_global_requests: deque[float] = deque()


def _initialize_model() -> None:
    global _model, _processor, _model_error

    try:
        import torch
        from transformers import AutoModelForAudioClassification, AutoProcessor

        torch.set_num_threads(max(1, min(4, os.cpu_count() or 1)))
        _processor = AutoProcessor.from_pretrained(
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
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str:
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


ADVICE = {
    "hungry": "قد يكون الجوع ضمن الاحتمالات. راجعي إشارات الرضاعة وموعدها المعتاد.",
    "belly_pain": "النموذج رجّح فئة ألم البطن؛ هذا لا يشخّص المغص. راقبي السياق واستشيري طبيب الطفل عند القلق.",
    "burping": "النموذج رجّح فئة الحاجة للتجشؤ. جرّبي التجشؤ بلطف مع دعم رأس الطفل ورقبته.",
    "discomfort": "النموذج رجّح انزعاجًا عامًا. افحصي الحفاض والملابس وحرارة المكان والضوضاء.",
    "tiredness": "النموذج رجّح التعب أو النعاس. خففي المثيرات وراقبي إشارات النعاس.",
    "unclear": "لم يتعرف النموذج على فئة واضحة. افحصي احتياجات الطفل وسياق البكاء.",
}


@app.get("/v1/health")
def health() -> dict[str, bool | str]:
    return {
        "status": "ok" if not _model_error else "model_unavailable",
        "model_ready": _model is not None and _processor is not None,
    }


@app.post("/v1/cry-analysis", response_model=AnalysisResponse)
async def analyze_cry(
    audio: UploadFile = File(...),
    uid: str = Depends(authenticated_user),
) -> AnalysisResponse:
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
