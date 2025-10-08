FROM cgr.dev/chainguard/nginx

LABEL org.opencontainers.image.source="https://github.com/ThorntonCloud/GitOps-App"
LABEL org.opencontainers.image.description="GitOps-managed Nginx for demo app"
LABEL org.opencontainers.image.vendor="ThorntonCloud"

USER 65532

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD [ "/usr/bin/wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health" ]

COPY nginx.conf /etc/nginx/nginx.conf

COPY version.json /usr/share/nginx/html/.version.json

COPY 404.html /usr/share/nginx/html/404.html
COPY 50x.html /usr/share/nginx/html/50x.html

EXPOSE 8080