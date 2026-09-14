FROM ghcr.io/flaresolverr/flaresolverr:latest

USER root

# Install ELMINYWAE API dependencies
RUN pip install --no-cache-dir fastapi uvicorn requests

# ============================================================
# ELMINYWAE API
# ============================================================
RUN cat > /app/elminywae_api.py <<'PY'
import requests
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

BACKEND = "http://127.0.0.1:8080"

app = FastAPI(
    title="ELMINYWAE",
    description="ELMINYWAE API powered by FlareSolverr",
    version="1.0.0"
)

@app.get("/")
def root():
    return {
        "status": "online",
        "service": "ELMINYWAE",
        "developer": "ELMINYWAE",
        "powered_by": "FlareSolverr",
        "version": "1.0.0"
    }

@app.get("/health")
def health():
    try:
        r = requests.get(
            f"{BACKEND}/health",
            timeout=10
        )

        try:
            data = r.json()
        except Exception:
            data = {
                "response": r.text
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
                "error": str(e)
            }
        )


@app.post("/v1")
async def v1(request: Request):

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

    try:
        response = requests.post(
            f"{BACKEND}/v1",
            json=body,
            timeout=180
        )

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

    except Exception as e:

        return JSONResponse(
            status_code=500,
            content={
                "status": "error",
                "service": "ELMINYWAE",
                "developer": "ELMINYWAE",
                "error": str(e)
            }
        )
PY


# ============================================================
# START SCRIPT
# ============================================================
RUN cat > /app/start_elminywae.sh <<'SH'
#!/bin/sh

echo ""
echo "=========================================="
echo "          ELMINYWAE API"
echo "          Powered by FlareSolverr"
echo "=========================================="
echo ""

# ------------------------------------------------------------
# FlareSolverr
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Wait for FlareSolverr
# ------------------------------------------------------------

echo "[ELMINYWAE] Waiting for FlareSolverr..."

i=0

while [ $i -lt 120 ]; do

    if wget -q \
        -O /dev/null \
        http://127.0.0.1:8080/health \
        2>/dev/null
    then
        echo ""
        echo "[ELMINYWAE] FlareSolverr is READY!"
        echo ""
        break
    fi

    i=$((i + 1))

    sleep 1

done


# ------------------------------------------------------------
# Check FlareSolverr
# ------------------------------------------------------------

if ! wget -q \
    -O /dev/null \
    http://127.0.0.1:8080/health \
    2>/dev/null
then

    echo ""
    echo "[ELMINYWAE] ERROR!"
    echo "[ELMINYWAE] FlareSolverr failed to start."
    echo ""

    kill "$FLARE_PID" 2>/dev/null

    exit 1

fi


# ------------------------------------------------------------
# Start ELMINYWAE
# ------------------------------------------------------------

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
echo "[ELMINYWAE] /v1"
echo ""

exec /usr/local/bin/python \
    -m uvicorn \
    elminywae_api:app \
    --host 0.0.0.0 \
    --port 8191
SH


RUN chmod +x /app/start_elminywae.sh


# ============================================================
# ENVIRONMENT
# ============================================================

ENV LOG_LEVEL=info
ENV LOG_HTML=false
ENV CAPTCHA_SOLVER=none
ENV LANG=en
ENV TZ=UTC


# ============================================================
# PORTS
# ============================================================

EXPOSE 8080
EXPOSE 8191


# ============================================================
# START
# ============================================================

CMD ["/app/start_elminywae.sh"]
