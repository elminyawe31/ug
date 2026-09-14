FROM ghcr.io/flaresolverr/flaresolverr:latest

USER root

# ============================================================
# ELMINYWAE API dependencies
# ============================================================

RUN pip install --no-cache-dir \
    fastapi \
    uvicorn \
    requests


# ============================================================
# ELMINYWAE API
# ============================================================

RUN cat > /app/elminywae_api.py <<'PY'
import requests

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


# FlareSolverr internal address
BACKEND = "http://127.0.0.1:8080"


app = FastAPI(
    title="ELMINYWAE",
    description="ELMINYWAE API powered by FlareSolverr",
    version="1.0.0"
)


# ============================================================
# HOME
# ============================================================

@app.get("/")
def root():

    return {
        "status": "online",
        "service": "ELMINYWAE",
        "developer": "ELMINYWAE",
        "powered_by": "FlareSolverr",
        "version": "1.0.0"
    }


# ============================================================
# HEALTH
# ============================================================

@app.get("/health")
def health():

    try:

        response = requests.get(
            f"{BACKEND}/health",
            timeout=10
        )

        try:
            data = response.json()
        except Exception:
            data = {
                "response": response.text
            }

        return {
            "status": "ok",
            "service": "ELMINYWAE",
            "developer": "ELMINYWAE",
            "flaresolverr": data
        }

    except Exception as e:

        return JSONResponse(
            status_code=503,
            content={
                "status": "error",
                "service": "ELMINYWAE",
                "developer": "ELMINYWAE",
                "error": "FlareSolverr is unavailable",
                "details": str(e)
            }
        )


# ============================================================
# FLARESOLVERR API
# ============================================================

@app.post("/v1")
async def v1(request: Request):

    # Read JSON
    try:

        body = await request.json()

    except Exception:

        return JSONResponse(
            status_code=400,
            content={
                "status": "error",
                "service": "ELMINYWAE",
                "developer": "ELMINYWAE",
                "error": "Invalid JSON"
            }
        )


    # Send request to FlareSolverr
    try:

        response = requests.post(
            f"{BACKEND}/v1",
            json=body,
            timeout=180
        )

    except requests.exceptions.RequestException as e:

        return JSONResponse(
            status_code=502,
            content={
                "status": "error",
                "service": "ELMINYWAE",
                "developer": "ELMINYWAE",
                "error": "FlareSolverr connection failed",
                "details": str(e)
            }
        )


    # Parse response
    try:

        data = response.json()

    except Exception:

        return JSONResponse(
            status_code=response.status_code,
            content={
                "service": "ELMINYWAE",
                "developer": "ELMINYWAE",
                "response": response.text
            }
        )


    # Add ELMINYWAE branding
    if isinstance(data, dict):

        data["service"] = "ELMINYWAE"
        data["developer"] = "ELMINYWAE"

        if isinstance(data.get("msg"), str):

            data["msg"] = data["msg"].replace(
                "FlareSolverr",
                "ELMINYWAE Solver"
            )


    return JSONResponse(
        status_code=response.status_code,
        content=data
    )


# ============================================================
# ENDPOINT INFO
# ============================================================

@app.get("/api")
def api_info():

    return {
        "name": "ELMINYWAE",
        "developer": "ELMINYWAE",
        "status": "online",
        "flaresolverr": "connected",
        "endpoints": {
            "home": "/",
            "health": "/health",
            "solver": "/v1"
        }
    }
PY


# ============================================================
# STARTUP SCRIPT
# ============================================================

RUN cat > /app/start_elminywae.sh <<'SH'
#!/bin/sh


echo ""
echo "=========================================="
echo "          ELMINYWAE API"
echo "          Powered by FlareSolverr"
echo "=========================================="
echo ""


# ============================================================
# Start FlareSolverr
# ============================================================

echo "[ELMINYWAE] Starting FlareSolverr..."
echo "[ELMINYWAE] FlareSolverr Port: 8080"

export HOST=0.0.0.0
export PORT=8080


/usr/bin/dumb-init -- \
    /usr/local/bin/python \
    -u \
    /app/flaresolverr.py &


FLARE_PID=$!


echo "[ELMINYWAE] FlareSolverr PID: $FLARE_PID"
echo "[ELMINYWAE] Waiting for FlareSolverr..."



# ============================================================
# Wait for FlareSolverr
# ============================================================

i=0

while [ $i -lt 120 ]; do

    # Check if process is still alive
    if ! kill -0 "$FLARE_PID" 2>/dev/null; then

        echo ""
        echo "[ELMINYWAE] ERROR: FlareSolverr stopped!"
        echo ""

        exit 1

    fi


    # Check HTTP server
    if wget \
        -q \
        -O /dev/null \
        http://127.0.0.1:8080/ \
        2>/dev/null
    then

        echo ""
        echo "[ELMINYWAE] FlareSolverr is READY!"
        break

    fi


    i=$((i + 1))

    sleep 1

done



# ============================================================
# Final process check
# ============================================================

if ! kill -0 "$FLARE_PID" 2>/dev/null; then

    echo ""
    echo "[ELMINYWAE] ERROR: FlareSolverr is not running!"
    echo ""

    exit 1

fi


echo ""
echo "=========================================="
echo "          ELMINYWAE IS READY"
echo "=========================================="
echo ""
echo "[ELMINYWAE] FlareSolverr : 8080"
echo "[ELMINYWAE] ELMINYWAE    : 8191"
echo ""
echo "[ELMINYWAE] Endpoints:"
echo "[ELMINYWAE] /"
echo "[ELMINYWAE] /health"
echo "[ELMINYWAE] /api"
echo "[ELMINYWAE] /v1"
echo ""
echo "=========================================="
echo ""


# ============================================================
# Start ELMINYWAE API
# ============================================================

exec /usr/local/bin/python \
    -m uvicorn \
    elminywae_api:app \
    --host 0.0.0.0 \
    --port 8191
SH


RUN chmod +x /app/start_elminywae.sh


# ============================================================
# FlareSolverr configuration
# ============================================================

ENV LOG_LEVEL=info
ENV LOG_HTML=false
ENV CAPTCHA_SOLVER=none
ENV LANG=en
ENV TZ=UTC

ENV HOST=0.0.0.0
ENV PORT=8080


# ============================================================
# Ports
# ============================================================

EXPOSE 8080
EXPOSE 8191


# ============================================================
# Start
# ============================================================

CMD ["/app/start_elminywae.sh"]
