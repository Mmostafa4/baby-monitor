FROM ghcr.io/cirruslabs/flutter:stable AS web-build

WORKDIR /workspace
COPY pubspec.yaml ./
COPY web ./web
RUN flutter pub get
COPY . .
RUN flutter build web --release --base-href /app/

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/tmp/hf-home \
    HF_HUB_DISABLE_TELEMETRY=1 \
    OMP_NUM_THREADS=1 \
    MKL_NUM_THREADS=1 \
    MALLOC_ARENA_MAX=2

RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 10001 app

WORKDIR /srv/baby-monitor
COPY backend/app/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu torch==2.14.0 \
    && pip install --no-cache-dir -r requirements.txt
COPY backend/app ./app
COPY --from=web-build /workspace/build/web ./web

USER 10001:10001
EXPOSE 8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1 --no-access-log --proxy-headers"]
