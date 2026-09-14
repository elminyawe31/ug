FROM ghcr.io/flaresolverr/flaresolverr:latest

ENV LOG_LEVEL=warning
ENV LOG_HTML=false
ENV CAPTCHA_SOLVER=none
ENV TZ=UTC
ENV LANG=en

WORKDIR /app

# ELMINYAWE API dependencies
RUN pip install --no-cache-dir fastapi uvicorn requests

# ============================================================
# ELMINYAWE API
# ============================================================

RUN cat > /app/elminyawe.py <<'PYEOF'
import requests
import uvicorn

from fastapi import FastAPI, Request
from fastapi.responses import Response

app = FastAPI(
    title="ELMINYAWE",
    description="ELMINYAWE FlareSolver API",
    version="1.0.0"
)

BACKEND = "http://127.0.0.1:8192"


def brand(data):
    if isinstance(data, dict):
        data["service"] = "ELMINYAWE"
        data["developer"] = "ELMINYAWE"

        if isinstance(data.get("msg"), str):
            data["msg"] = data["msg"].replace(
                "FlareSolverr",
                "ELMINYAWE Solver"
            )

    return data


@app.get("/")
async def root():
    return {
        "status": "ready",
        "service": "ELMINYAWE",
        "developer": "ELMINYAWE",
        "solver": "FlareSolverr",
        "api": "/v1",
        "health": "/health"
    }


@app.get("/health")
async def health():
    try:
        r = requests.get(
            f"{BACKEND}/health",
            timeout=10
        )

        data = r.json()
        return brand(data)

    except Exception as e:
        return {
            "status": "starting",
            "service": "ELMINYAWE",
            "developer": "ELMINYAWE",
            "solver": "starting",
            "error": str(e)
        }


@app.post("/v1")
async def v1(request: Request):
    try:
        payload = await request.json()

        r = requests.post(
            f"{BACKEND}/v1",
            json=payload,
            timeout=300
        )

        try:
            data = r.json()
            return brand(data)

        except Exception:
            return Response(
                content=r.content,
                status_code=r.status_code,
                media_type=r.headers.get(
                    "content-type",
                    "application/json"
                )
            )

    except Exception as e:
        return {
            "status": "error",
            "service": "ELMINYAWE",
            "developer": "ELMINYAWE",
            "error": str(e)
        }


@app.api_route(
    "/{path:path}",
    methods=[
        "GET",
        "POST",
        "PUT",
        "DELETE",
        "PATCH",
        "OPTIONS"
    ]
)
async def proxy(request: Request, path: str):

    # Don't expose internal details unnecessarily
    if path in ["v1", "health"]:
        return {
            "service": "ELMINYAWE",
            "developer": "ELMINYAWE"
        }

    try:
        url = f"{BACKEND}/{path}"

        if request.query_params:
            url += f"?{request.query_params}"

        body = None

        if request.method in [
            "POST",
            "PUT",
            "PATCH"
        ]:
            body = await request.body()

        r = requests.request(
            request.method,
            url,
            data=body,
            headers={
                k: v
                for k, v in request.headers.items()
                if k.lower() not in [
                    "host",
                    "content-length"
                ]
            },
            timeout=300
        )

        try:
            return brand(r.json())

        except Exception:
            return Response(
                content=r.content,
                status_code=r.status_code,
                media_type=r.headers.get(
                    "content-type",
                    "application/octet-stream"
                )
            )

    except Exception as e:
        return {
            "status": "error",
            "service": "ELMINYAWE",
            "developer": "ELMINYAWE",
            "error": str(e)
        }


if __name__ == "__main__":
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8191,
        log_level="warning"
    )
PYEOF

# ============================================================
# Startup script
# ============================================================

RUN cat > /app/start.sh <<'BASH'
#!/bin/bash

set -e

echo "=============================================="
echo "       ELMINYAWE FlareSolver API"
echo "=============================================="

echo "[1/3] Starting FlareSolverr..."

# Start the ORIGINAL FlareSolverr entrypoint
/entrypoint.sh &
SOLVER_PID=$!

echo "[2/3] Waiting for FlareSolverr..."

for i in $(seq 1 90); do

    if curl -sf http://127.0.0.1:8192/health >/dev/null 2>&1; then
        echo "FlareSolverr is READY!"
        break
    fi

    if [ "$i" = "90" ]; then
        echo "ERROR: FlareSolverr did not start."
        exit 1
    fi

    sleep 2
done

echo "[3/3] Starting ELMINYAWE API..."

python /app/elminyawe.py
BASH

RUN chmod +x /app/start.sh

# ============================================================
# Public API
# ============================================================

EXPOSE 8191

# ============================================================
# ELMINYAWE
# ============================================================

CMD ["/app/start.sh"]
