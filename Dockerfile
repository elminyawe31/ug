FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ============================================================
# SYSTEM
# ============================================================

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    wget \
    curl \
    git \
    ca-certificates \
    gnupg \
    unzip \
    xvfb \
    chromium-browser \
    chromium-chromedriver \
    libnss3 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libgbm1 \
    libasound2t64 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libxshmfence1 \
    libu2f-udev \
    fonts-liberation \
    fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# PYTHON
# ============================================================

RUN pip3 install --break-system-packages --no-cache-dir \
    fastapi \
    uvicorn \
    requests \
    selenium \
    pydantic \
    loguru \
    beautifulsoup4 \
    func-timeout

# ============================================================
# FLARESOLVERR
# ============================================================

WORKDIR /opt

RUN git clone --depth 1 \
    https://github.com/FlareSolverr/FlareSolverr.git \
    /opt/FlareSolverr

WORKDIR /opt/FlareSolverr

# Install FlareSolverr Python dependencies
RUN pip3 install --break-system-packages --no-cache-dir \
    -r requirements.txt

# ============================================================
# ELMINYAWE
# ============================================================

WORKDIR /app

RUN cat > /app/proxy.py <<'PYEOF'
import requests
import uvicorn

from fastapi import FastAPI, Request
from fastapi.responses import Response

BACKEND = "http://127.0.0.1:8192"

app = FastAPI(
    title="ELMINYAWE",
    description="ELMINYAWE FlareSolver API",
    version="1.0"
)


def brand(data):

    if isinstance(data, dict):

        if isinstance(data.get("msg"), str):
            data["msg"] = data["msg"].replace(
                "FlareSolverr",
                "ELMINYAWE Solver"
            )

        data["service"] = "ELMINYAWE"
        data["developer"] = "ELMINYAWE"

    return data


@app.get("/")
async def root():

    return {
        "status": "online",
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

        return brand(r.json())

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

        data = await request.json()

        r = requests.post(
            f"{BACKEND}/v1",
            json=data,
            timeout=300
        )

        try:

            return brand(r.json())

        except:

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
            headers=dict(request.headers),
            timeout=300
        )

        try:

            return brand(r.json())

        except:

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


if __name__ == "__main__":

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8191,
        log_level="warning"
    )
PYEOF

# ============================================================
# START SCRIPT
# ============================================================

RUN cat > /app/start.sh <<'BASH'
#!/bin/bash

set -e

echo "================================================"
echo "        ELMINYAWE FlareSolver API"
echo "================================================"

# ------------------------------------------------
# Start virtual display
# ------------------------------------------------

echo "[1/4] Starting Xvfb..."

Xvfb :99 \
    -screen 0 1920x1080x24 \
    -ac \
    +extension RANDR \
    > /tmp/xvfb.log 2>&1 &

export DISPLAY=:99

sleep 2

# ------------------------------------------------
# Start FlareSolverr
# ------------------------------------------------

echo "[2/4] Starting FlareSolverr..."

cd /opt/FlareSolverr

python3 flaresolverr.py \
    --host 127.0.0.1 \
    --port 8192 \
    > /tmp/flaresolverr.log 2>&1 &

FLARE_PID=$!

# ------------------------------------------------
# Wait for FlareSolverr
# ------------------------------------------------

echo "[3/4] Waiting for FlareSolverr..."

READY=0

for i in $(seq 1 90); do

    if curl -sf \
        http://127.0.0.1:8192/health \
        >/dev/null 2>&1; then

        READY=1
        break

    fi

    if ! kill -0 $FLARE_PID 2>/dev/null; then

        echo ""
        echo "FlareSolverr crashed!"
        echo ""
        cat /tmp/flaresolverr.log
        exit 1

    fi

    sleep 2

done

if [ "$READY" != "1" ]; then

    echo ""
    echo "FlareSolverr failed to start."
    echo ""
    cat /tmp/flaresolverr.log

    exit 1

fi

echo ""
echo "FlareSolverr is READY!"
echo ""

# ------------------------------------------------
# Start ELMINYAWE
# ------------------------------------------------

echo "[4/4] Starting ELMINYAWE API..."

cd /app

exec python3 proxy.py
BASH

RUN chmod +x /app/start.sh

# ============================================================
# API
# ============================================================

EXPOSE 8191

# ============================================================
# START
# ============================================================

CMD ["/app/start.sh"]
