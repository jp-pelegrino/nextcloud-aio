#!/bin/sh

# Show warning if vm.overcommit is disabled
# Memory overcommit must be enabled for safe operation of Valkey/Redis
if [ "$(sysctl -n vm.overcommit_memory 2>/dev/null || echo 0)" != "1" ]; then
    echo "WARNING: Memory overcommit is disabled but necessary for safe operation"
    echo "See https://github.com/nextcloud/all-in-one/discussions/1731 how to enable overcommit"
fi

# Start Valkey server
# Valkey is fully compatible with Redis protocol (RESP) and uses the same server binary name
echo "Valkey server starting..."

if [ -n "$REDIS_HOST_PASSWORD" ]; then
    echo "Starting Valkey with authentication enabled"
    exec valkey-server --requirepass "$REDIS_HOST_PASSWORD" --loglevel warning
else
    echo "WARNING: Starting Valkey without authentication (not recommended for production)"
    exec valkey-server --loglevel warning
fi
