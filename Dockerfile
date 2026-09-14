FROM docker.io/kasmweb/ubuntu-jammy-desktop:1.18.0

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PW=12345678
ENV PORT=6901

# =========================================================
# Remove problematic repositories
# =========================================================

RUN rm -f \
    /etc/apt/sources.list.d/hashicorp.list \
    /etc/apt/sources.list.d/hashicorp.sources \
    /etc/apt/sources.list.d/terraform.list \
    2>/dev/null || true

# =========================================================
# Install required packages
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
# Give kasm-user full passwordless sudo
# =========================================================

RUN echo 'kasm-user ALL=(ALL) NOPASSWD:ALL' \
        > /etc/sudoers.d/kasm-user && \
    chmod 440 /etc/sudoers.d/kasm-user

# =========================================================
# Install Brave Browser
# =========================================================

RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-apt-keyring.gpg \
        -o /etc/apt/keyrings/brave-browser-archive-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > /etc/apt/sources.list.d/brave-browser-release.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends brave-browser && \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# Install Cloudflare Tunnel
# =========================================================

RUN curl -L \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# =========================================================
# Startup script
# =========================================================

RUN cat > /usr/local/bin/start.sh <<'EOF'
#!/bin/bash

set -e

echo ""
echo "=============================================="
echo " ELMINYAWE KASM DESKTOP"
echo "=============================================="
echo ""

echo "[1] Starting Kasm..."

/dockerstartup/kasm_default_profile.sh \
    /dockerstartup/vnc_startup.sh \
    /dockerstartup/kasm_startup.sh \
    --wait &

KASM_PID=$!

echo "[2] Kasm PID: $KASM_PID"
echo ""

echo "[3] Waiting for Kasm port 6901..."

KASM_READY=0

for i in $(seq 1 120); do

    if ss -lnt 2>/dev/null | grep -q ':6901 '; then
        KASM_READY=1

        echo ""
        echo "=============================================="
        echo " KASM PORT 6901 IS READY"
        echo "=============================================="
        echo ""

        break
    fi

    echo "Waiting for Kasm... $i/120"

    sleep 2

done

echo ""
echo "================ PORT CHECK ================"
ss -lntp || true
echo "============================================="
echo ""

# =========================================================
# Kasm failed
# =========================================================

if [ "$KASM_READY" -ne 1 ]; then

    echo ""
    echo "=============================================="
    echo " ERROR: KASM DID NOT OPEN PORT 6901"
    echo "=============================================="
    echo ""

    echo "===== KASM PROCESSES ====="

    ps aux | grep -E \
        'Xvnc|kasmvnc|websockify|kasm|vnc' \
        | grep -v grep || true

    echo ""
    echo "===== LISTENING PORTS ====="

    ss -lntp || true

    echo ""
    echo "===== POSSIBLE KASM/VNC LOGS ====="

    find /var/log /tmp \
        -type f \
        \( \
            -iname '*kasm*' \
            -o -iname '*vnc*' \
        \) \
        -print 2>/dev/null \
        | head -50 || true

    echo ""
    echo "===== PROCESS STATUS ====="

    ps auxww || true

    echo ""
    echo "Kasm process exited or failed to start."

    wait "$KASM_PID" || true

    exit 1

fi

# =========================================================
# Test local Kasm
# =========================================================

echo "[4] Testing local Kasm..."

if curl -k -I \
    --connect-timeout 10 \
    https://127.0.0.1:6901 \
    >/tmp/kasm-curl.txt 2>&1; then

    echo "Kasm HTTPS is responding."

else

    echo "Kasm port is open but HTTPS test failed."

fi

echo ""

cat /tmp/kasm-curl.txt 2>/dev/null || true

echo ""

# =========================================================
# Start Cloudflare Quick Tunnel
# =========================================================

echo "=============================================="
echo " [5] STARTING CLOUDFLARE QUICK TUNNEL"
echo "=============================================="
echo ""

echo "Your random public URL will appear below."
echo ""

/usr/local/bin/cloudflared tunnel \
    --no-autoupdate \
    --url https://127.0.0.1:6901 \
    --no-tls-verify &

CF_PID=$!

echo ""
echo "Cloudflared PID: $CF_PID"
echo ""

# =========================================================
# Keep container alive
# =========================================================

wait "$KASM_PID"
EOF

RUN chmod +x /usr/local/bin/start.sh

# =========================================================
# Railway / Kasm
# =========================================================

EXPOSE 6901

USER root

ENTRYPOINT ["/usr/local/bin/start.sh"]
