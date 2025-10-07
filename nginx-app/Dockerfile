FROM cgr.dev/chainguard/nginx

COPY index.html.template /temp/
COPY docker-entrypoint.sh /

RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD ["nginx", "-g", "daemon off;"]

#COPY index.html /usr/share/nginx/html/index.html

EXPOSE 8080