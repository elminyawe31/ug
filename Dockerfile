FROM kasmweb/ubuntu-jammy-desktop:1.18.0

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN rm -f \
    /etc/apt/sources.list.d/hashicorp.list \
    /etc/apt/sources.list.d/hashicorp.sources \
    /etc/apt/sources.list.d/hashicorp*.list

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

RUN echo 'kasm-user ALL=(ALL) NOPASSWD:ALL' \
    > /etc/sudoers.d/kasm-user && \
    chmod 440 /etc/sudoers.d/kasm-user

RUN curl -fsS https://dl.brave.com/install.sh | bash && \
    apt-get update && \
    apt-get install -y brave-browser && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf /usr/bin/brave-browser /usr/local/bin/brave

RUN curl -L \
    --fail \
    --show-error \
    --silent \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

ENV CF_TUNNEL_TOKEN="eyJhIjoiMGZhYWYyYzU1YzJjNmRiMzM4Yzk3ZDU1YTE4MmNiNTkiLCJ0IjoiZGUzNGEyYzYtMTFhNy00NjdjLWI5ZjMtMGUxYTdkYjA0M2ZhIiwicyI6IllqZGtZamMyTkdRdFpXSTJNaTAwWkRjNExXSTNZV1V0WXpZMll6SXlNemszTVRrMCJ9"

RUN mkdir -p /etc/supervisor/conf.d /var/log/supervisor

# Diagnostic script
RUN cat > /usr/local/bin/diagnostic.sh <<'EOF'
#!/bin/bash

while true; do

    {
        echo
        echo "=========================================="
        echo "DIAGNOSTIC $(date)"
        echo "=========================================="

        echo
        echo "===== LISTENING PORTS ====="
        ss -lntp 2>&1

        echo
        echo "===== PORT 6901 ====="
        ss -lntp 2>&1 | grep 6901 || echo "PORT 6901 NOT FOUND"

        echo
        echo "===== HTTPS LOCAL TEST ====="
        curl -k -I --connect-timeout 5 https://127.0.0.1:6901 2>&1 || true

        echo
        echo "===== PROCESS CHECK ====="
        ps aux | grep -E 'kasm|Xvnc|websockify|kasmvnc' | grep -v grep || true

        echo
        echo "===== CLOUDFLARED PROCESS ====="
        ps aux | grep cloudflared | grep -v grep || true

        echo
        echo "=========================================="

    } > /tmp/diagnostic.log 2>&1

    cat /tmp/diagnostic.log

    sleep 10

done
EOF

RUN chmod +x /usr/local/bin/diagnostic.sh

RUN cat > /etc/supervisor/conf.d/kasm-cloudflare.conf <<'EOF'
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log
pidfile=/var/run/supervisord.pid
loglevel=info
user=root

[program:kasm]
command=/dockerstartup/kasm_default_profile.sh /dockerstartup/vnc_startup.sh /dockerstartup/kasm_startup.sh --wait
user=kasm-user
environment=HOME="/home/kasm-user",USER="kasm-user",DISPLAY=":1"
autostart=true
autorestart=true
startsecs=5
startretries=20
priority=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
stopasgroup=true
killasgroup=true

[program:cloudflared]
command=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token %(ENV_CF_TUNNEL_TOKEN)s
autostart=true
autorestart=true
startsecs=5
startretries=20
priority=20
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
stopasgroup=true
killasgroup=true

[program:diagnostic]
command=/usr/local/bin/diagnostic.sh
autostart=true
autorestart=true
startsecs=1
priority=30
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
stopasgroup=true
killasgroup=true
EOF

RUN chown -R kasm-user:kasm-user /home/kasm-user

WORKDIR /home/kasm-user

USER root

ENTRYPOINT ["/usr/bin/supervisord"]
CMD ["-c", "/etc/supervisor/conf.d/kasm-cloudflare.conf"]
