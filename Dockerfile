FROM ghcr.io/flaresolverr/flaresolverr:latest

USER root

# ============================================================
# ELMINYWAE dependencies
# ============================================================

RUN pip install --no-cache-dir fastapi uvicorn requests


# ============================================================
# ELMINYWAE API
# ============================================================

RUN cat > /app/elminywae_api.py <<'PY'
import requests
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

FLARESOLVERR = "http://127.0.0.1:8080"

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
        "api_port": 8191,
        "solver_port": 8080
    }


@app.get("/health")
def health():
    try:
        r = requests.get(
            f"{FLARESOLVERR}/health",
            timeout=10
        )

        try:
            solver = r.json()
        except Exception:
            solver = {
                "response": r.text
            }

        return {
            "status": "ok",
            "service": "ELMINYWAE",
            "developer": "ELMINYWAE",
            "flaresolverr": solver
        }

    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={
                "status": "error",
                "service": "ELMINYWAE",
                "developer": "ELMINYWAE",
                "flaresolverr": "offline",
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
        r = requests.post(
            f"{FLARESOLVERR}/v1",
            json=body,
            timeout=180
        )

        try:
            data = r.json()
        except Exception:
            data = {
                "response": r.text
            }

        if isinstance(data, dict):

            data["service"] = "ELMINYWAE"
            data["developer"] = "ELMINYWAE"

            if isinstance(data.get("msg"), str):
                data["msg"] = data["msg"].replace(
                    "FlareSolverr",
                    "ELMINYWAE Solver"
                )

        return JSONResponse(
            status_code=r.status_code,
            content=data
        )

    except Exception as e:

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
PY


# ============================================================
# START SCRIPT
# ============================================================

RUN cat > /app/start_elminywae.sh <<'SH'
#!/bin/sh

echo ""
echo "=========================================="
echo "          ELMINYWAE"
echo "          Powered by FlareSolverr"
echo "=========================================="
echo ""

# ------------------------------------------------------------
# FlareSolverr = 8080
# ------------------------------------------------------------

export HOST=0.0.0.0
export PORT=8080

echo "[ELMINYWAE] Starting FlareSolverr on :8080..."

/usr/local/bin/python -u /app/flaresolverr.py &
FLARE_PID=$!

echo "[ELMINYWAE] FlareSolverr PID: $FLARE_PID"

# ------------------------------------------------------------
# ELMINYWAE = 8191
# ------------------------------------------------------------

echo ""
echo "[ELMINYWAE] Starting ELMINYWAE API on :8191..."
echo ""

exec /usr/local/bin/python \
    -m uvicorn \
    elminywae_api:app \
    --host 0.0.0.0 \
    --port 8191
SH


RUN chmod +x /app/start_elminywae.sh


# ============================================================
# Environment
# ============================================================

ENV LOG_LEVEL=info
ENV LOG_HTML=false
ENV CAPTCHA_SOLVER=none
ENV LANG=en
ENV TZ=UTC

# FlareSolverr internal port
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
