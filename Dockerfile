FROM kasmweb/ubuntu-jammy-desktop:1.18.0

USER root

ENV DEBIAN_FRONTEND=noninteractive

# =========================================================
# Remove broken HashiCorp repository
# =========================================================

RUN rm -f \
    /etc/apt/sources.list.d/hashicorp.list \
    /etc/apt/sources.list.d/hashicorp.sources \
    /etc/apt/sources.list.d/hashicorp*.list

# =========================================================
# System packages
# =========================================================

RUN apt-get update && \
    apt-get install -y \
        sudo \
        curl \
        wget \
        ca-certificates \
        gnupg \
        software-properties-common \
        apt-transport-https \
        git \
        nano \
        vim \
        htop \
        unzip \
        zip \
        jq \
        net-tools \
        iputils-ping \
        procps \
        psmisc \
        lsof \
        dnsutils \
        locales \
        supervisor && \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# Passwordless sudo
# =========================================================

RUN echo 'kasm-user ALL=(ALL) NOPASSWD:ALL' \
    > /etc/sudoers.d/kasm-user && \
    chmod 440 /etc/sudoers.d/kasm-user

# =========================================================
# Brave
# =========================================================

RUN curl -fsS https://dl.brave.com/install.sh | bash && \
    apt-get update && \
    apt-get install -y brave-browser && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf /usr/bin/brave-browser /usr/local/bin/brave

# =========================================================
# Cloudflared
# =========================================================

RUN curl -L \
    --fail \
    --show-error \
    --silent \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# =========================================================
# Cloudflare Tunnel Token
# =========================================================

ENV CF_TUNNEL_TOKEN="eyJhIjoiMGZhYWYyYzU1YzJjNmRiMzM4Yzk3ZDU1YTE4MmNiNTkiLCJ0IjoiZGUzNGEyYzYtMTFhNy00NjdjLWI5ZjMtMGUxYTdkYjA0M2ZhIiwicyI6IllqZGtZamMyTkdRdFpXSTJNaTAwWkRjNExXSTNZV1V0WXpZMll6SXlNemszTVRrMCJ9"

# =========================================================
# Kasm startup wrapper
# =========================================================

RUN cat > /usr/local/bin/start-kasm.sh <<'EOF'
#!/bin/bash

exec /dockerstartup/kasm_default_profile.sh --tail-log
EOF

RUN chmod +x /usr/local/bin/start-kasm.sh

# =========================================================
# Supervisor
# =========================================================

RUN mkdir -p /etc/supervisor/conf.d

RUN cat > /etc/supervisor/conf.d/kasm-cloudflare.conf <<'EOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisord.log
pidfile=/var/run/supervisord.pid

[program:kasm]
command=/usr/local/bin/start-kasm.sh
user=kasm-user
environment=HOME="/home/kasm-user",USER="kasm-user"
autostart=true
autorestart=true
startsecs=5
startretries=20
priority=10
stdout_logfile=/var/log/kasm.log
stderr_logfile=/var/log/kasm-error.log
stopasgroup=true
killasgroup=true

[program:cloudflared]
command=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token %(ENV_CF_TUNNEL_TOKEN)s
autostart=true
autorestart=true
startsecs=5
startretries=20
priority=20
stdout_logfile=/var/log/cloudflared.log
stderr_logfile=/var/log/cloudflared-error.log
stopasgroup=true
killasgroup=true
EOF

# =========================================================
# Permissions
# =========================================================

RUN chown -R kasm-user:kasm-user /home/kasm-user

# =========================================================
# Kasm WebSocket/Web UI
# =========================================================

EXPOSE 6901

# =========================================================
# Start both services
# =========================================================

ENTRYPOINT ["/usr/bin/supervisord"]
CMD ["-c", "/etc/supervisor/conf.d/kasm-cloudflare.conf"]
