FROM ghcr.io/flaresolverr/flaresolverr:latest

USER root

RUN pip install --no-cache-dir fastapi uvicorn requests


# ============================================================
# ELMINYAWE API
# ============================================================

RUN cat > /app/elminyawe_api.py <<'PY'
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import requests
import json

FLARESOLVERR_URL = "http://127.0.0.1:8080"

app = FastAPI(
    title="ELMINYAWE",
    description="ELMINYAWE API powered by FlareSolverr",
    version="1.0.0"
)


# ============================================================
# ROOT
# ============================================================

@app.get("/")
async def root():
    return {
        "status": "online",
        "service": "ELMINYAWE",
        "developer": "ELMINYAWE",
        "powered_by": "FlareSolverr",
        "api_port": 8191,
        "flaresolverr_port": 8080
    }


# ============================================================
# HEALTH
# ============================================================

@app.get("/health")
async def health():

    try:

        response = requests.get(
            f"{FLARESOLVERR_URL}/health",
            timeout=10
        )

        return {
            "status": "online",
            "service": "ELMINYAWE",
            "developer": "ELMINYAWE",
            "flaresolverr": response.json()
        }

    except Exception as e:

        return JSONResponse(
            status_code=502,
            content={
                "status": "offline",
                "service": "ELMINYAWE",
                "developer": "ELMINYAWE",
                "error": str(e)
            }
        )


# ============================================================
# ELMINYAWE → FLARESOLVERR PROXY
# ============================================================

@app.post("/v1")
async def flaresolverr_proxy(request: Request):

    try:

        # Receive RAW body
        raw_body = await request.body()

        # Parse JSON
        try:

            body = json.loads(
                raw_body.decode("utf-8")
            )

        except Exception as e:

            return JSONResponse(
                status_code=400,
                content={
                    "service": "ELMINYAWE",
                    "developer": "ELMINYAWE",
                    "error": "Invalid JSON",
                    "details": str(e)
                }
            )

        # Send JSON to internal FlareSolverr
        response = requests.post(
            f"{FLARESOLVERR_URL}/v1",
            json=body,
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json"
            },
            timeout=180
        )

        # Parse FlareSolverr response
        try:

            data = response.json()

        except Exception:

            return JSONResponse(
                status_code=response.status_code,
                content={
                    "service": "ELMINYAWE",
                    "developer": "ELMINYAWE",
                    "response": response.text
                }
            )

        # ====================================================
        # ELMINYAWE BRANDING
        # ====================================================

        if isinstance(data, dict):

            data["service"] = "ELMINYAWE"
            data["developer"] = "ELMINYAWE"

            if "msg" in data and isinstance(data["msg"], str):

                data["msg"] = data["msg"].replace(
                    "FlareSolverr",
                    "ELMINYAWE Solver"
                )

        # Return original FlareSolverr result
        return JSONResponse(
            status_code=response.status_code,
            content=data
        )

    except requests.exceptions.RequestException as e:

        return JSONResponse(
            status_code=502,
            content={
                "service": "ELMINYAWE",
                "developer": "ELMINYAWE",
                "error": "FlareSolverr connection failed",
                "details": str(e)
            }
        )

    except Exception as e:

        return JSONResponse(
            status_code=500,
            content={
                "service": "ELMINYAWE",
                "developer": "ELMINYAWE",
                "error": str(e)
            }
        )


# ============================================================
# 404
# ============================================================

@app.api_route(
    "/{path:path}",
    methods=[
        "GET",
        "POST",
        "PUT",
        "PATCH",
        "DELETE"
    ]
)
async def catch_all(request: Request, path: str):

    return JSONResponse(
        status_code=404,
        content={
            "service": "ELMINYAWE",
            "developer": "ELMINYAWE",
            "error": "Endpoint not found"
        }
    )
PY


# ============================================================
# START SCRIPT
# ============================================================

RUN cat > /app/start_elminyawe.sh <<'SH'
#!/bin/sh

echo ""
echo "=============================================="
echo "              ELMINYAWE"
echo "       FlareSolverr API Gateway"
echo "=============================================="
echo ""

echo "[ELMINYAWE] Starting FlareSolverr..."
echo "[ELMINYAWE] Internal FlareSolverr: 127.0.0.1:8080"

export HOST=127.0.0.1
export PORT=8080

/usr/local/bin/python -u /app/flaresolverr.py &

FLARE_PID=$!

echo "[ELMINYAWE] FlareSolverr PID: $FLARE_PID"

echo "[ELMINYAWE] Waiting for FlareSolverr..."

i=0

while [ $i -lt 60 ]; do

    if curl -fsS http://127.0.0.1:8080/health >/dev/null 2>&1; then
        echo "[ELMINYAWE] FlareSolverr READY!"
        break
    fi

    i=$((i + 1))
    sleep 1

done

if ! kill -0 "$FLARE_PID" 2>/dev/null; then

    echo "[ELMINYAWE] ERROR: FlareSolverr stopped!"

    exit 1

fi

echo ""
echo "[ELMINYAWE] Starting ELMINYAWE API..."
echo "[ELMINYAWE] API: 0.0.0.0:8191"
echo "[ELMINYAWE] Solver: 127.0.0.1:8080"
echo ""

exec /usr/local/bin/python -m uvicorn elminyawe_api:app \
    --host 0.0.0.0 \
    --port 8191
SH

RUN chmod +x /app/start_elminyawe.sh


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

CMD ["/app/start_elminyawe.sh"]
