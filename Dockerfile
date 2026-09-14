FROM docker.io/kasmweb/ubuntu-jammy-desktop:1.18.0

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PW=12345678
ENV PORT=6901

# Remove problematic HashiCorp repositories
RUN rm -f \
    /etc/apt/sources.list.d/hashicorp.list \
    /etc/apt/sources.list.d/hashicorp.sources \
    /etc/apt/sources.list.d/terraform.list \
    2>/dev/null || true

# Basic packages
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

# Full sudo for kasm-user
RUN echo 'kasm-user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/kasm-user && \
    chmod 440 /etc/sudoers.d/kasm-user

# Brave Browser
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-apt-keyring.gpg \
        -o /etc/apt/keyrings/brave-browser-archive-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > /etc/apt/sources.list.d/brave-browser-release.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends brave-browser && \
    rm -rf /var/lib/apt/lists/*

# Cloudflared
RUN curl -L \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# Startup script
RUN cat > /usr/local/bin/start.sh <<'EOF'
#!/bin/bash

set -e

echo "=============================================="
echo " ELMINYAWE KASM DESKTOP"
echo "=============================================="

echo "[1] Starting Kasm..."

# Start Kasm in background
/dockerstartup/kasm_default_profile.sh \
    /dockerstartup/vnc_startup.sh \
    /dockerstartup/kasm_startup.sh \
    --wait &

KASM_PID=$!

echo "[2] Kasm PID: $KASM_PID"

echo "[3] Waiting for Kasm port 6901..."

for i in $(seq 1 120); do

    if ss -lnt 2>/dev/null | grep -q ':6901 '; then
        echo "=============================================="
        echo " KASM PORT 6901 IS READY"
        echo "=============================================="
        break
    fi

    echo "Waiting for Kasm... $i/120"
    sleep 2

done

echo ""
echo "===== PORT CHECK ====="
ss -lntp || true
echo "======================"
echo ""

if ! ss -lnt 2>/dev/null | grep -q ':6901 '; then
    echo "ERROR: Kasm did NOT open port 6901"
    echo ""
    echo "===== KASM PROCESSES ====="
    ps aux | grep -E 'Xvnc|kasmvnc|websockify|kasm|vnc' | grep -v grep || true
    echo ""
    echo "===== KASM LOGS ====="
    find /var/log /tmp -type f \
        \( -iname '*kasm*' -o -iname '*vnc*' \) \
        -print 2>/dev/null | head -50 || true

    wait $KASM_PID
    exit 1
fi

echo "[4] Starting Cloudflare Quick Tunnel..."
echo ""
echo "=============================================="
echo " YOUR RANDOM CLOUDFLARE URL WILL APPEAR BELOW"
echo "=============================================="
echo ""

# Quick Tunnel
cloudflared tunnel \
    --no-autoupdate \
    --url https://127.0.0.1:6901 \
    --no-tls-verify &

CF_PID=$!

echo ""
echo "Cloudflare PID: $CF_PID"
echo ""

# Keep container alive while both processes run
wait $KASM_PID
EOF

RUN chmod +x /usr/local/bin/start.sh

EXPOSE 6901

USER root

ENTRYPOINT ["/usr/local/bin/start.sh"]
