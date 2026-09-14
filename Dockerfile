FROM ghcr.io/flaresolverr/flaresolverr:latest

ENV LOG_LEVEL=warning
ENV LOG_HTML=false
ENV CAPTCHA_SOLVER=none
ENV LANG=en
ENV TZ=UTC

EXPOSE 8191
