# syntax=docker/dockerfile:latest
# Valkey - Redis-compatible in-memory data store
# Valkey is a Redis fork that maintains full RESP (Redis Serialization Protocol) compatibility
# Official repository: https://github.com/valkey-io/valkey

FROM valkey/valkey:7.2-alpine

COPY --chmod=775 start.sh /start.sh

RUN set -ex; \
    apk upgrade --no-cache -a; \
    apk add --no-cache openssl bash; \
    \
# Give root a random password for security
    echo "root:$(openssl rand -base64 12)" | chpasswd;

COPY --chmod=775 healthcheck.sh /healthcheck.sh

# Run as non-root user for security
USER 999

ENTRYPOINT ["/start.sh"]

HEALTHCHECK CMD /healthcheck.sh

LABEL com.centurylinklabs.watchtower.enable="false" \
    org.label-schema.vendor="Nextcloud" \
    org.label-schema.name="Nextcloud AIO Valkey" \
    org.label-schema.description="Valkey (Redis-compatible) cache for Nextcloud AIO"
