#!/bin/bash

# Health check for Valkey container
# Valkey is RESP-compatible, so we can use valkey-cli (or redis-cli if available as alias)
# The valkey-cli command is compatible with redis-cli

# Use valkey-cli for health check with PING command
if [ -n "$REDIS_HOST_PASSWORD" ]; then
    valkey-cli -a "$REDIS_HOST_PASSWORD" PING || exit 1
else
    valkey-cli PING || exit 1
fi
