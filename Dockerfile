FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ============================================================
# Ubuntu Base + Required Packages
# ============================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tmux \
    zip \
    unzip \
    tar \
    rsync \
    net-tools \
    iproute2 \
    iputils-ping \
    dnsutils \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    locales \
    tzdata \
    cron \
    bash-completion \
    man-db \
    jq \
    less \
    file \
    passwd \
    openssh-client \
    sqlite3 \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    xvfb \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2t64 \
    fonts-liberation \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Python
# ============================================================

RUN python3 -m pip install --break-system-packages \
    fastapi \
    uvicorn \
    requests

# ============================================================
# ttyd
# ============================================================

RUN arch="$(dpkg --print-architecture)" && \
    case "$arch" in \
        amd64) t=x86_64 ;; \
        arm64) t=aarch64 ;; \
        *) t="$arch" ;; \
    esac && \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${t}" \
    -o /usr/local/bin/ttyd && \
    chmod +x /usr/local/bin/ttyd

# ============================================================
# Cloudflared
# ============================================================

RUN arch="$(dpkg --print-architecture)" && \
    case "$arch" in \
        amd64) t=amd64 ;; \
        arm64) t=arm64 ;; \
        *) t="$arch" ;; \
    esac && \
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${t}" \
    -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# ============================================================
# ELMINYAWE Solver
# ============================================================

WORKDIR /opt/elminyawe

RUN wget -qO- https://api.github.com/repos/FlareSolverr/FlareSolverr/releases/latest \
    | grep '"browser_download_url":' \
    | grep 'linux' \
    | cut -d '"' -f 4 \
    | head -n 1 \
    | xargs -r wget -O /tmp/flaresolverr.tar.gz

RUN if [ -s /tmp/flaresolverr.tar.gz ]; then \
        mkdir -p /opt/flaresolverr && \
        tar -xzf /tmp/flaresolverr.tar.gz -C /opt/flaresolverr --strip-components=1 || true; \
    fi && \
    rm -f /tmp/flaresolverr.tar.gz

# ============================================================
# ELMINYAWE Proxy
# ============================================================

COPY <<'PYEOF' /opt/elminyawe/proxy.py
import requests
from fastapi import FastAPI, Request
from fastapi.responses import Response
import uvicorn

BACKEND = "http://127.0.0.1:8192"

app = FastAPI(
    title="ELMINYAWE",
    description="Developed by ELMINYAWE"
)

def brand(data):
    if isinstance(data, dict):
        if "msg" in data and isinstance(data["msg"], str):
            data["msg"] = data["msg"].replace(
                "FlareSolverr",
                "ELMINYAWE Solver"
            )

        data["service"] = "ELMINYAWE"
        data["developer"] = "ELMINYAWE"

    return data


@app.get("/health")
async def health():
    try:
        response = requests.get(
            f"{BACKEND}/health",
            timeout=5
        )

        return brand(response.json())

    except Exception:
        return {
            "status": "starting",
            "service": "ELMINYAWE",
            "developer": "ELMINYAWE"
        }


@app.get("/")
async def root():
    try:
        response = requests.get(
            f"{BACKEND}/",
            timeout=5
        )

        return brand(response.json())

    except Exception:
        return {
            "status": "starting",
            "service": "ELMINYAWE",
            "developer": "ELMINYAWE"
        }


@app.post("/v1")
async def proxy_v1(request: Request):
    try:
        data = await request.json()

        response = requests.post(
            f"{BACKEND}/v1",
            json=data,
            timeout=180
        )

        return brand(response.json())

    except Exception as e:
        return {
            "error": str(e),
            "service": "ELMINYAWE",
            "developer": "ELMINYAWE"
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
async def catch_all(
    request: Request,
    path: str
):
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

        response = requests.request(
            request.method,
            url,
            data=body,
            headers=dict(request.headers),
            timeout=180
        )

        try:
            return brand(response.json())

        except Exception:
            return Response(
                content=response.content,
                status_code=response.status_code,
                media_type=response.headers.get(
                    "content-type",
                    "application/octet-stream"
                )
            )

    except Exception as e:
        return {
            "error": str(e),
            "service": "ELMINYAWE",
            "developer": "ELMINYAWE"
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
# Environment
# ============================================================

ENV LOG_LEVEL=warning
ENV LANG=en

# ============================================================
# Startup
# ============================================================

COPY <<'BASH' /entrypoint.sh
#!/usr/bin/env bash

set -e

echo "=========================================================="
echo "        ELMINYAWE Ubuntu Environment"
echo "=========================================================="

# ------------------------------------------------------------
# SSH
# ------------------------------------------------------------

mkdir -p /run/sshd

echo "root:ELMINYAWE" | chpasswd

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' \
    /etc/ssh/sshd_config

sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
    /etc/ssh/sshd_config

/usr/sbin/sshd

# ------------------------------------------------------------
# ttyd
# ------------------------------------------------------------

ttyd \
    --port 8081 \
    --writable \
    --credential "root:ELMINYAWE" \
    /bin/bash -l &

# ------------------------------------------------------------
# FlareSolverr
# ------------------------------------------------------------

echo "Starting ELMINYAWE Solver..."

if [ -x "/opt/flaresolverr/flaresolverr" ]; then

    LOG_LEVEL=warning \
    /opt/flaresolverr/flaresolverr \
        > /var/log/elminyawe-solver.log 2>&1 &

elif [ -x "/opt/flaresolverr/FlareSolverr" ]; then

    LOG_LEVEL=warning \
    /opt/flaresolverr/FlareSolverr \
        > /var/log/elminyawe-solver.log 2>&1 &

else

    echo "WARNING: FlareSolverr executable was not found."

fi

# ------------------------------------------------------------
# Wait for Solver
# ------------------------------------------------------------

echo "Waiting for ELMINYAWE Solver..."

for i in $(seq 1 60); do

    if curl -sf http://127.0.0.1:8192/health >/dev/null 2>&1; then
        echo "ELMINYAWE Solver is READY."
        break
    fi

    sleep 2

done

# ------------------------------------------------------------
# ELMINYAWE Proxy
# ------------------------------------------------------------

echo "Starting ELMINYAWE API on port 8191..."

python3 /opt/elminyawe/proxy.py &

# ------------------------------------------------------------
# Cloudflare Quick Tunnel for terminal
# ------------------------------------------------------------

touch /tmp/cf.log

(
    while true; do

        cloudflared tunnel \
            --url http://127.0.0.1:8081 \
            >> /tmp/cf.log 2>&1 || true

        sleep 5

    done
) &

# ------------------------------------------------------------
# Display status
# ------------------------------------------------------------

(
    sleep 15

    while true; do

        URL=$(grep -o \
            'https://[a-z0-9-]*\.trycloudflare\.com' \
            /tmp/cf.log \
            | tail -n 1)

        echo ""
        echo "=========================================================="
        echo "             ELMINYAWE IS READY"
        echo "=========================================================="
        echo "API      : http://0.0.0.0:8191"
        echo "Health   : http://0.0.0.0:8191/health"
        echo "Terminal : ${URL:-Waiting for Cloudflare...}"
        echo "SSH      : port 22"
        echo "ttyd     : port 8081"
        echo "Solver   : internal port 8192"
        echo "Developer: ELMINYAWE"
        echo "=========================================================="
        echo ""

        sleep 30

    done

) &

# Keep container alive

wait
BASH

RUN chmod +x /entrypoint.sh

# ============================================================
# Ports
# ============================================================

EXPOSE 22
EXPOSE 8081
EXPOSE 8191

# ============================================================
# Start
# ============================================================

CMD ["/entrypoint.sh"]
