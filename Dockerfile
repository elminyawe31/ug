FROM ghcr.io/flaresolverr/flaresolverr:latest

USER root

RUN pip install --no-cache-dir fastapi uvicorn requests

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
        "powered_by": "FlareSolverr"
    }

@app.get("/health")
def health():
    try:
        r = requests.get(f"{BACKEND}/health", timeout=10)
        data = r.json()

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
    body = await request.json()

    try:
        r = requests.post(
            f"{BACKEND}/v1",
            json=body,
            timeout=180
        )

        try:
            data = r.json()
        except Exception:
            return JSONResponse(
                status_code=r.status_code,
                content={
                    "service": "ELMINYWAE",
                    "developer": "ELMINYWAE",
                    "response": r.text
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
                "error": str(e)
            }
        )
PY

RUN cat > /app/start_elminywae.sh <<'SH'
#!/bin/sh

echo "=========================================="
echo "          ELMINYWAE API"
echo "          Powered by FlareSolverr"
echo "=========================================="

echo "[ELMINYWAE] FlareSolverr is using port 8080"
echo "[ELMINYWAE] API is using port 8191"

echo "[ELMINYWAE] Starting API..."

exec /usr/local/bin/python -m uvicorn elminywae_api:app \
    --host 0.0.0.0 \
    --port 8191
SH

RUN chmod +x /app/start_elminywae.sh

ENV LOG_LEVEL=info
ENV LOG_HTML=false
ENV CAPTCHA_SOLVER=none
ENV HOST=0.0.0.0
ENV PORT=8080
ENV LANG=en
ENV TZ=UTC

EXPOSE 8080
EXPOSE 8191

CMD ["/app/start_elminywae.sh"]
