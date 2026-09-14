FROM docker.io/kasmweb/ubuntu-jammy-desktop:1.18.0

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PW=12345678
ENV PORT=6901

# =========================================================
# REMOVE BROKEN THIRD-PARTY APT REPOSITORIES
# =========================================================
RUN rm -f \
    /etc/apt/sources.list.d/hashicorp.list \
    /etc/apt/sources.list.d/hashicorp.sources \
    /etc/apt/sources.list.d/terraform.list \
    2>/dev/null || true

# =========================================================
# SYSTEM PACKAGES
# =========================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sudo \
        curl \
        wget \
        ca-certificates \
        gnupg \
        supervisor \
        procps \
        iproute2 \
        net-tools \
        dbus-x11 \
        xauth \
        xvfb \
    && rm -rf /var/lib/apt/lists/*

# =========================================================
# KASM USER - FULL SUDO
# =========================================================
RUN echo 'kasm-user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/kasm-user && \
    chmod 440 /etc/sudoers.d/kasm-user

# =========================================================
# BRAVE BROWSER
# =========================================================
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSLo /etc/apt/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
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
# CLOUDFLARE TUNNEL TOKEN
# =========================================================
ENV CF_TUNNEL_TOKEN="eyJhIjoiMGZhYWYyYzU1YzJjNmRiMzM4Yzk3ZDU1YTE4MmNiNTkiLCJ0IjoiZGUzNGEyYzYtMTFhNy00NjdjLWI5ZjMtMGUxYTdkYjA0M2ZhIiwicyI6IllqZGtZamMyTkdRdFpXSTJNaTAwWkRjNExXSTNZV1V0WXpZMll6SXlNemszTVRrMCJ9"

# =========================================================
# SUPERVISOR
# =========================================================
RUN mkdir -p /etc/supervisor/conf.d /var/log/supervisor

RUN cat > /etc/supervisor/conf.d/kasm-cloudflare.conf <<'EOF'
[supervisord]
nodaemon=true
logfile=/dev/null
pidfile=/var/run/supervisord.pid

[program:kasm]
command=/dockerstartup/kasm_default_profile.sh /dockerstartup/vnc_startup.sh /dockerstartup/kasm_startup.sh --wait
directory=/home/kasm-user
user=root
priority=10
autostart=true
autorestart=true
startsecs=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
stopasgroup=true
killasgroup=true

[program:cloudflared]
command=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token %(ENV_CF_TUNNEL_TOKEN)s
user=root
priority=20
autostart=true
autorestart=true
startsecs=5
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
stopasgroup=true
killasgroup=true
EOF

# =========================================================
# START SCRIPT
# =========================================================
RUN cat > /usr/local/bin/start-all.sh <<'EOF'
#!/bin/bash

echo "================================================="
echo " ELMINYAWE KASM + CLOUDFLARE"
echo "================================================="

echo "[INFO] Running as:"
id

echo "[INFO] Starting Supervisor..."

exec /usr/bin/supervisord \
    -c /etc/supervisor/conf.d/kasm-cloudflare.conf
EOF

RUN chmod +x /usr/local/bin/start-all.sh

# =========================================================
# RAILWAY
# =========================================================
USER root

EXPOSE 6901

ENTRYPOINT ["/usr/local/bin/start-all.sh"]
