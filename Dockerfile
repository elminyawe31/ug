FROM kasmweb/ubuntu-jammy-desktop:1.18.0

USER root

ENV DEBIAN_FRONTEND=noninteractive

# =========================================================
# Remove problematic repository
# =========================================================
RUN rm -f \
    /etc/apt/sources.list.d/hashicorp.list \
    /etc/apt/sources.list.d/hashicorp.sources \
    /etc/apt/sources.list.d/hashicorp*.list

# =========================================================
# Install required packages
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
# Full sudo for kasm-user
# =========================================================
RUN echo 'kasm-user ALL=(ALL) NOPASSWD:ALL' \
    > /etc/sudoers.d/kasm-user && \
    chmod 440 /etc/sudoers.d/kasm-user

# =========================================================
# Brave Browser
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
# Make the old Cloudflare origin hostname resolve locally
#
# Your Cloudflare tunnel currently uses:
# https://ubuntu-desktop:6901
#
# Since both services are now in the same container,
# point ubuntu-desktop -> localhost.
# =========================================================
RUN echo "127.0.0.1 ubuntu-desktop" >> /etc/hosts

# =========================================================
# Cloudflare Tunnel Token
# =========================================================
ENV CF_TUNNEL_TOKEN="eyJhIjoiMGZhYWYyYzU1YzJjNmRiMzM4Yzk3ZDU1YTE4MmNiNTkiLCJ0IjoiZGUzNGEyYzYtMTFhNy00NjdjLWI5ZjMtMGUxYTdkYjA0M2ZhIiwicyI6IllqZGtZamMyTkdRdFpXSTJNaTAwWkRjNExXSTNZV1V0WXpZMll6SXlNemszTVRrMCJ9"

# =========================================================
# Supervisor
# =========================================================
RUN mkdir -p /etc/supervisor/conf.d /var/log/supervisor

RUN cat > /etc/supervisor/conf.d/kasm-cloudflare.conf <<'EOF'
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log
pidfile=/var/run/supervisord.pid
loglevel=info

[program:kasm]
command=/dockerstartup/kasm_default_profile.sh /dockerstartup/vnc_startup.sh /dockerstartup/kasm_startup.sh --wait
user=kasm-user
environment=HOME="/home/kasm-user",USER="kasm-user",DISPLAY=":1"
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
# Kasm user
# =========================================================
USER kasm-user

ENV HOME=/home/kasm-user

WORKDIR /home/kasm-user

# =========================================================
# Start both Kasm + Cloudflare
# =========================================================
USER root

ENTRYPOINT ["/usr/bin/supervisord"]
CMD ["-c", "/etc/supervisor/conf.d/kasm-cloudflare.conf"]
