ARG VERSION=1.31.5
ARG REGISTRY=docker.io/library
FROM $REGISTRY/nginx:$VERSION-alpine

COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

RUN mkdir -p /tmp/nginx/{logs,client,fastcgi,proxy,scgi,uwsgi} && \
    chgrp -R 0 /tmp/nginx /var/cache/nginx && \
    chmod -R g+rwX /tmp/nginx /var/cache/nginx

WORKDIR /app

RUN chgrp -R 0 /app && \
    chmod -R g+rwX /app

EXPOSE 8080

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "nginx", "-g", "daemon off;" ]

USER 1031
