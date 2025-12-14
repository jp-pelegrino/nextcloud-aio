# Docker Compose Deployment with Valkey and Cloudflare Tunnel Support

This guide describes how to deploy Nextcloud AIO using the enhanced `docker-compose.yml` configuration that includes:

- **Valkey**: A Redis-compatible cache server (Redis fork with RESP protocol support)
- **Configurable Network Binding**: Control which network interfaces expose services
- **Cloudflare Tunnel Support**: Optional in-compose tunnel service for secure external access
- **Environment-driven Configuration**: All settings configurable via `.env` file

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration Options](#configuration-options)
- [Deployment Scenarios](#deployment-scenarios)
- [Cloudflare Tunnel Setup](#cloudflare-tunnel-setup)
- [Valkey (Redis Replacement)](#valkey-redis-replacement)
- [Testing and Validation](#testing-and-validation)
- [Troubleshooting](#troubleshooting)

## Quick Start

### 1. Prerequisites

- Docker Engine 20.10+ and Docker Compose V2 installed
- For Cloudflare Tunnel: A Cloudflare account with Zero Trust enabled
- Linux, macOS, or Windows with Docker Desktop

### 2. Initial Setup

```bash
# Clone the repository (if not already done)
git clone https://github.com/jp-pelegrino/nextcloud-aio.git
cd nextcloud-aio

# Copy the example environment file
cp .env.example .env

# Edit .env to set your configuration
nano .env  # or use your preferred editor
```

### 3. Configure Environment

At minimum, set these values in `.env`:

```env
# Network binding (0.0.0.0 for LAN access, 127.0.0.1 for localhost only)
BIND_ADDR=0.0.0.0

# Set a strong Redis/Valkey password
REDIS_HOST_PASSWORD=your-strong-password-here

# Skip domain validation if using Cloudflare Tunnel or reverse proxy
SKIP_DOMAIN_VALIDATION=true
```

### 4. Build and Start

```bash
# Build the Valkey image and start all services
docker-compose up --build -d

# View logs
docker-compose logs -f

# Check service health
docker-compose ps
```

### 5. Access Nextcloud AIO

- **Admin Interface**: `https://your-host-ip:8080`
- **Nextcloud HTTP**: `http://your-host-ip:80`
- **Nextcloud HTTPS**: `https://your-host-ip:8443`

## Configuration Options

### Network Binding (`BIND_ADDR`)

Controls which network interface services listen on:

| Value | Behavior | Use Case |
|-------|----------|----------|
| `0.0.0.0` | Listen on all interfaces | LAN access from any device |
| `127.0.0.1` | Listen on localhost only | Cloudflare Tunnel or local reverse proxy |
| `192.168.1.10` | Specific IP address | Bind to specific network interface |

### Port Configuration

Override default ports in `.env`:

```env
HTTP_HOST_PORT=80
HTTPS_HOST_PORT=8443
ADMIN_HOST_PORT=8080
```

### Redis/Valkey Password

**IMPORTANT**: Always set a strong password for production:

```env
REDIS_HOST_PASSWORD=your-secure-random-password
```

Generate a secure password:
```bash
openssl rand -base64 32
```

## Deployment Scenarios

### Scenario 1: Local LAN Access Only

Best for home networks or internal deployments without external access.

**Configuration** (`.env`):
```env
BIND_ADDR=0.0.0.0
SKIP_DOMAIN_VALIDATION=false
# Keep cloudflared service commented in docker-compose.yml
```

**Access**:
- From LAN: `http://192.168.1.x:80` (replace with your host IP)
- Admin: `https://192.168.1.x:8080`

### Scenario 2: Cloudflare Tunnel Only (No Direct LAN Access)

Best for maximum security when you only want access via Cloudflare.

**Configuration** (`.env`):
```env
BIND_ADDR=127.0.0.1
SKIP_DOMAIN_VALIDATION=true
CF_TUNNEL_TOKEN=your-cloudflare-tunnel-token
```

**Additional Steps**:
1. Uncomment the `cloudflared` service in `docker-compose.yml`
2. Configure Cloudflare Tunnel to point to `http://nextcloud-aio-mastercontainer:80`

**Access**:
- Via Cloudflare: `https://your-domain.example.com`
- Admin (localhost only): `https://localhost:8080`

### Scenario 3: Both LAN and Cloudflare Tunnel

Best for flexibility when you want both local and remote access.

**Configuration** (`.env`):
```env
BIND_ADDR=0.0.0.0
SKIP_DOMAIN_VALIDATION=true
CF_TUNNEL_TOKEN=your-cloudflare-tunnel-token
```

**Additional Steps**:
1. Uncomment the `cloudflared` service in `docker-compose.yml`

**Access**:
- Via Cloudflare: `https://your-domain.example.com`
- From LAN: `http://192.168.1.x:80`
- Admin: `https://192.168.1.x:8080`

## Cloudflare Tunnel Setup

### Option 1: Using Tunnel Token (Recommended)

1. **Create a Cloudflare Tunnel**:
   - Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
   - Navigate to Access → Tunnels
   - Click "Create a tunnel"
   - Name it (e.g., "nextcloud-aio")
   - Save the tunnel

2. **Get the Tunnel Token**:
   - After creating the tunnel, copy the token from the setup command
   - It looks like: `eyJhIjoiXXXXX...`

3. **Configure the Tunnel**:
   - Add a public hostname:
     - **Subdomain**: `cloud` (or your choice)
     - **Domain**: `example.com` (your domain)
     - **Service**: `http://nextcloud-aio-mastercontainer:80` (or `https://...8443` for HTTPS)

4. **Update `.env`**:
   ```env
   CF_TUNNEL_TOKEN=eyJhIjoiXXXXX...
   ```

5. **Uncomment cloudflared service** in `docker-compose.yml`:
   ```yaml
   cloudflared:
     image: cloudflare/cloudflared:latest
     restart: always
     container_name: nextcloud-aio-cloudflared
     networks:
       - nextcloud-aio
     command: tunnel --no-autoupdate run --token ${CF_TUNNEL_TOKEN}
     environment:
       TUNNEL_TOKEN: ${CF_TUNNEL_TOKEN}
     depends_on:
       - nextcloud-aio-mastercontainer
   ```

6. **Start the services**:
   ```bash
   docker-compose up -d
   ```

### Option 2: Using Credentials File

For advanced configurations, you can use a credentials file:

1. Create `cloudflared-config.yml`:
   ```yaml
   tunnel: your-tunnel-id
   credentials-file: /etc/cloudflared/credentials.json
   ingress:
     - hostname: cloud.example.com
       service: http://nextcloud-aio-mastercontainer:80
     - service: http_status:404
   ```

2. Update `.env`:
   ```env
   CF_TUNNEL_CREDFILE=./cloudflared-credentials.json
   CF_TUNNEL_CONFIG=./cloudflared-config.yml
   ```

3. Modify the cloudflared service in `docker-compose.yml` to use volumes.

## Valkey (Redis Replacement)

### What is Valkey?

Valkey is a high-performance key-value datastore that is a fork of Redis. It maintains full compatibility with the Redis Serialization Protocol (RESP), making it a drop-in replacement for Redis.

**Benefits**:
- Fully open-source (BSD-3-Clause license)
- 100% Redis protocol compatible
- Active development and community support
- Same performance characteristics as Redis

### How It Works in This Setup

1. **Service Name**: The service is named `redis` in `docker-compose.yml` to maintain compatibility with Nextcloud's expectations.
2. **Image**: Uses the official `valkey/valkey:7.2-alpine` image.
3. **Authentication**: Supports password authentication via `REDIS_HOST_PASSWORD`.
4. **Health Checks**: Uses `valkey-cli` (equivalent to `redis-cli`) for health monitoring.

### Verifying Valkey is Running

```bash
# Check service status
docker-compose ps redis

# View Valkey logs
docker-compose logs redis

# Test Valkey connection (from within container)
docker-compose exec redis valkey-cli PING
# Expected output: PONG

# Test with password
docker-compose exec redis valkey-cli -a your-password PING
```

### Migration from Redis

If migrating from an existing Redis setup:

1. Valkey can read Redis RDB and AOF files
2. Simply point the Valkey data volume to your existing Redis data
3. No data conversion needed due to protocol compatibility

## Testing and Validation

### Pre-Deployment Checks

Before starting services, verify your configuration:

```bash
# Validate docker-compose.yml syntax
docker-compose config

# Check environment variables
docker-compose config | grep -E "BIND_ADDR|REDIS_HOST_PASSWORD|SKIP_DOMAIN"
```

### Build and Health Checks

```bash
# Build Valkey image
docker-compose build redis

# Start services
docker-compose up -d

# Wait 60 seconds for services to initialize
sleep 60

# Check health status
docker-compose ps

# All services should show "healthy" or "running"
```

### Network Binding Validation

#### Test BIND_ADDR=0.0.0.0 (LAN Access)

```bash
# From another machine on your LAN
curl -I http://192.168.1.x:80
# Should receive HTTP response headers

# Test from localhost
curl -I http://localhost:80
# Should also work
```

#### Test BIND_ADDR=127.0.0.1 (Localhost Only)

```bash
# From localhost (should work)
curl -I http://localhost:80

# From another LAN machine (should fail)
curl -I http://192.168.1.x:80
# Should get "Connection refused" or timeout
```

### Valkey Connection Test

```bash
# Test PING without password
docker-compose exec redis valkey-cli PING

# Test PING with password
docker-compose exec redis valkey-cli -a "${REDIS_HOST_PASSWORD}" PING

# Check Valkey info
docker-compose exec redis valkey-cli -a "${REDIS_HOST_PASSWORD}" INFO server
```

### Cloudflare Tunnel Validation

```bash
# Check tunnel status
docker-compose logs cloudflared

# Look for successful connection message:
# "Connection <UUID> registered"
# "Started tunnel connection"

# Test external access
curl -I https://cloud.example.com
# Should return Nextcloud headers
```

### Complete Validation Checklist

- [ ] Valkey container is healthy (`docker-compose ps`)
- [ ] Nextcloud AIO mastercontainer is healthy
- [ ] Valkey responds to PING command
- [ ] Can access admin interface on configured port
- [ ] LAN access works (if BIND_ADDR=0.0.0.0)
- [ ] LAN access blocked (if BIND_ADDR=127.0.0.1)
- [ ] Cloudflare Tunnel connected (if enabled)
- [ ] External domain resolves to Nextcloud (if tunnel enabled)
- [ ] No secrets in `.env` file committed to git

## Troubleshooting

### Valkey Container Won't Start

**Symptom**: Valkey container exits immediately or restarts constantly.

**Solutions**:
1. Check logs: `docker-compose logs redis`
2. Verify memory overcommit is enabled:
   ```bash
   sysctl vm.overcommit_memory
   # Should return: vm.overcommit_memory = 1
   
   # If not, enable it:
   sudo sysctl vm.overcommit_memory=1
   
   # Make permanent:
   echo "vm.overcommit_memory = 1" | sudo tee -a /etc/sysctl.conf
   ```

### Valkey Health Check Failing

**Symptom**: Container shows as "unhealthy" in `docker-compose ps`.

**Solutions**:
1. Check if password is set correctly:
   ```bash
   docker-compose exec redis valkey-cli -a "your-password" PING
   ```
2. Verify `REDIS_HOST_PASSWORD` in `.env` matches healthcheck script
3. Check Valkey logs for errors

### Cannot Access Nextcloud from LAN

**Symptom**: Connection refused when accessing from another device.

**Solutions**:
1. Verify `BIND_ADDR=0.0.0.0` in `.env`
2. Check firewall rules:
   ```bash
   sudo ufw status  # Ubuntu/Debian
   sudo firewall-cmd --list-all  # CentOS/RHEL
   ```
3. Ensure ports are not already in use:
   ```bash
   sudo netstat -tulpn | grep -E ':80|:8080|:8443'
   ```

### Cloudflare Tunnel Not Connecting

**Symptom**: Tunnel logs show connection errors or timeout.

**Solutions**:
1. Verify tunnel token is correct in `.env`
2. Check tunnel configuration in Cloudflare dashboard
3. Ensure Nextcloud service name is correct: `nextcloud-aio-mastercontainer`
4. Check tunnel logs:
   ```bash
   docker-compose logs cloudflared
   ```
5. Verify network connectivity:
   ```bash
   docker-compose exec cloudflared ping -c 3 nextcloud-aio-mastercontainer
   ```

### Domain Validation Errors

**Symptom**: Nextcloud AIO shows domain validation errors.

**Solutions**:
1. Ensure `SKIP_DOMAIN_VALIDATION=true` in `.env` when using Cloudflare Tunnel
2. Restart services after changing `.env`:
   ```bash
   docker-compose down
   docker-compose up -d
   ```
3. Check Nextcloud trusted domains in `config.php`

### Services Not Using Updated .env Values

**Symptom**: Changes to `.env` don't take effect.

**Solutions**:
1. Recreate containers (not just restart):
   ```bash
   docker-compose down
   docker-compose up -d
   ```
2. For environment changes, rebuild if needed:
   ```bash
   docker-compose up --build -d
   ```

## Advanced Configuration

### Custom Valkey Image

To use a different Valkey image or version:

```env
# In .env
VALKEY_IMAGE=valkey/valkey:7.2.5-alpine
```

Or to use your own build:
```bash
# Build with custom tag
docker-compose build --build-arg VALKEY_VERSION=7.2.5 redis

# Update .env
VALKEY_IMAGE=nextcloud-aio-valkey:custom
```

### Multiple Network Interfaces

Bind different services to different interfaces by modifying `docker-compose.yml`:

```yaml
ports:
  # HTTP on all interfaces
  - "0.0.0.0:${HTTP_HOST_PORT:-80}:80"
  # Admin only on localhost
  - "127.0.0.1:${ADMIN_HOST_PORT:-8080}:8080"
  # HTTPS on specific IP
  - "192.168.1.10:${HTTPS_HOST_PORT:-8443}:8443"
```

### Docker Network MTU

For networks with special MTU requirements:

```env
# In .env
DOCKER_NETWORK_MTU=1440
```

Then uncomment the MTU configuration in `docker-compose.yml`.

## Security Best Practices

1. **Always use strong passwords**:
   ```bash
   # Generate secure password
   openssl rand -base64 32
   ```

2. **Use HTTPS origins with Cloudflare Tunnel** when possible:
   ```yaml
   # In tunnel config
   service: https://nextcloud-aio-mastercontainer:8443
   ```

3. **Restrict admin interface access**:
   ```env
   BIND_ADDR=127.0.0.1  # Admin only from localhost
   ```
   Then use SSH tunnel for remote admin access.

4. **Never commit `.env` file**:
   ```bash
   # Verify .env is in .gitignore
   cat .gitignore | grep .env
   ```

5. **Keep images updated**:
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

6. **Review container logs regularly**:
   ```bash
   docker-compose logs --tail=100 --follow
   ```

## Support and Resources

- **Nextcloud AIO Documentation**: [https://github.com/nextcloud/all-in-one](https://github.com/nextcloud/all-in-one)
- **Valkey Documentation**: [https://valkey.io/documentation](https://valkey.io)
- **Cloudflare Tunnel Docs**: [https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- **Docker Compose Reference**: [https://docs.docker.com/compose/compose-file/](https://docs.docker.com/compose/compose-file/)

## Contributing

Found an issue or have an improvement? Please open an issue or pull request in the repository.
