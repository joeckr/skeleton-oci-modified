ARG VERSION=3.24
ARG REGISTRY=docker.io/library
FROM $REGISTRY/alpine:$VERSION

WORKDIR /app

COPY --chmod=755 entrypoint.sh /app/entrypoint.sh

RUN chgrp -R 0 /app && \
    chmod -R g+rwX /app

EXPOSE 8080

ENTRYPOINT [ "/app/entrypoint.sh" ]

USER 1031
