# syntax=docker/dockerfile:1

FROM python:3.11-slim AS builder

WORKDIR /build

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

COPY requirements.txt .

RUN python -m pip wheel --wheel-dir /wheels --requirement requirements.txt


FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8083

WORKDIR /app

RUN addgroup --system app \
    && adduser --system --ingroup app --no-create-home app

COPY --from=builder /wheels /wheels
COPY requirements.txt .

RUN python -m pip install --no-index --find-links=/wheels --requirement requirements.txt \
    && rm -rf /wheels

COPY --chown=app:app app.py .

USER app

EXPOSE 8083

CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT:-8083} app:app"]
