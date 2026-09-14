FROM docker.io/kasmweb/ubuntu-jammy-desktop:1.18.0

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PW=12345678
ENV PORT=6901

# =========================================================
# FIX BROKEN APT REPOSITORIES FROM KASM IMAGE
# =========================================================
RUN rm -f \
    /etc/apt/sources.list.d/hashicorp.list \
    /etc/apt/sources.list.d/hashicorp.sources \
    /etc/apt/sources.list.d/terraform.list \
    2>/dev/null || true

# =========================================================
# PACKAGES
# =========================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sudo \
        curl \
        wget \
        ca-certificates \
        gnupg \
        procps \
        iproute2 \
        net-tools \
        dbus-x11 \
        xauth \
        xvfb \
    && rm -rf /var/lib/apt/lists/*

# =========================================================
# KASM USER
# =========================================================
RUN echo 'kasm-user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/kasm-user && \
    chmod 440 /etc/sudoers.d/kasm-user

# =========================================================
# BRAVE
# =========================================================
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSLo /etc/apt/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-apt-keyring.gpg || \
    curl -fsSLo /etc/apt/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

RUN echo "deb [signed-by=/etc/apt/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > /etc/apt/sources.list.d/brave-browser-release.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends brave-browser && \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# CLOUDFLARED
# =========================================================
RUN curl -L \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# =========================================================
# CLOUDFLARE TOKEN
# =========================================================
ENV CF_TUNNEL_TOKEN="eyJhIjoiMGZhYWYyYzU1YzJjNmRiMzM4Yzk3ZDU1YTE4MmNiNTkiLCJ0IjoiZGUzNGEyYzYtMTFhNy00NjdjLWI5ZjMtMGUxYTdkYjA0M2ZhIiwicyI6IllqZGtZamMyTkdRdFpXSTJNaTAwWkRjNExXSTNZV1V0WXpZMll6SXlNemszTVRrMCJ9"

# =========================================================
# START EVERYTHING
# =========================================================
RUN cat > /usr/local/bin/start-kasm-cloudflare.sh <<'EOF'
#!/bin/bash

set -e

echo "=============================================="
echo " ELMINYAWE KASM + CLOUDFLARE"
echo "=============================================="

echo "[1] Starting Cloudflare Tunnel..."

/usr/local/bin/cloudflared tunnel \
    --no-autoupdate \
    run \
    --token "$CF_TUNNEL_TOKEN" &

CLOUDFLARED_PID=$!

echo "[2] Cloudflared PID: $CLOUDFLARED_PID"

echo "[3] Starting Kasm as ROOT..."

exec /dockerstartup/kasm_default_profile.sh \
    /dockerstartup/vnc_startup.sh \
    /dockerstartup/kasm_startup.sh \
    --wait

EOF

RUN chmod +x /usr/local/bin/start-kasm-cloudflare.sh

USER root

EXPOSE 6901

ENTRYPOINT ["/usr/local/bin/start-kasm-cloudflare.sh"]
