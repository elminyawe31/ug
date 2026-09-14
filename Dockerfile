FROM ghcr.io/flaresolverr/flaresolverr:latest

# ============================================================
# ELMINYAWE FlareSolverr API
# ============================================================

ENV LOG_LEVEL=warning
ENV LOG_HTML=false
ENV CAPTCHA_SOLVER=none
ENV TZ=UTC
ENV LANG=en

# FlareSolverr API
ENV HOST=0.0.0.0
ENV PORT=8191

EXPOSE 8191

# ============================================================
# Start FlareSolverr
# ============================================================

CMD ["python", "/app/src/flaresolverr.py"]
