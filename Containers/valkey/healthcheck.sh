#!/bin/sh

# Health check for Valkey container
# Valkey is RESP-compatible, so we can use valkey-cli (or redis-cli if available as alias)
# The valkey-cli command is compatible with redis-cli

# Use REDISCLI_AUTH environment variable to avoid exposing password in process list
if [ -n "$REDIS_HOST_PASSWORD" ]; then
    REDISCLI_AUTH="$REDIS_HOST_PASSWORD" valkey-cli PING || exit 1
else
    valkey-cli PING || exit 1
fi
