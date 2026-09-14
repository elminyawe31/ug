FROM ghcr.io/flaresolverr/flaresolverr:latest

ENV LOG_LEVEL=info
ENV LOG_HTML=false
ENV CAPTCHA_SOLVER=none
ENV HOST=0.0.0.0

EXPOSE 8191

CMD ["/bin/sh", "-c", "export PORT=${PORT:-8191}; exec /usr/local/bin/python -u /app/flaresolverr.py"]
