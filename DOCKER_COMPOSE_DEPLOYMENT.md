# Docker Compose Deployment with Valkey and Cloudflare Tunnel Support

> [!NOTE]
> This repository contains two compose files:
> - `compose.yaml` - Standard Nextcloud AIO deployment
> - `docker-compose.yml` - Enhanced deployment with Valkey and Cloudflare Tunnel support
>
> **To use this enhanced deployment, you must specify `-f docker-compose.yml` in all `docker compose` commands.**

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
git clone https://github.com/nextcloud/all-in-one.git
cd all-in-one

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

> [!IMPORTANT]
> This repository contains both `compose.yaml` (standard deployment) and `docker-compose.yml` (enhanced deployment with Valkey/Cloudflare Tunnel).
> You must specify `-f docker-compose.yml` to use the enhanced configuration.

```bash
# Build the Valkey image and start all services
docker compose -f docker-compose.yml up --build -d

# View logs
docker compose -f docker-compose.yml logs -f

# Check service health
docker compose -f docker-compose.yml ps
```

### 5. Access Nextcloud AIO

> [!NOTE]
> **About SSL/TLS Certificates**:
> - Nextcloud AIO uses **self-signed certificates** by default
> - HTTP requests are automatically redirected to HTTPS
> - Your browser will show security warnings - this is normal
> - Accept the security exception or add the certificate to your trust store
> - For production, configure a proper domain with valid certificates

**Access URLs** (replace `your-host-ip` with your actual IP or localhost):
- **Admin Interface**: `https://your-host-ip:8080` (or `:8083` if using ADMIN_HOST_PORT=8083)
- **Nextcloud HTTP**: `http://your-host-ip:80` (redirects to HTTPS, or `:8082` if using HTTP_HOST_PORT=8082)
- **Nextcloud HTTPS**: `https://your-host-ip:8443` (or `:7443` if using HTTPS_HOST_PORT=7443)

**Testing with curl**:
```bash
# HTTP will redirect to HTTPS with self-signed cert
curl -L http://localhost:8082  # Will redirect to HTTPS

# HTTPS with self-signed cert (use -k to skip verification)
curl -k https://localhost:7443  # -k flag ignores certificate validation

# Or to see the redirect:
curl -v http://localhost:8082  # Will show 301/302 redirect
```

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

> [!NOTE]
> **Expected Behavior for All Scenarios**:
> - HTTP requests automatically redirect to HTTPS
> - Self-signed SSL certificates are used (browser warnings are normal)
> - Accept certificate warnings in your browser or use `curl -k` for testing
> - For production with valid certificates, use a proper domain or Cloudflare Tunnel

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
# DO NOT set APACHE_PORT for in-compose cloudflared
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
# DO NOT set APACHE_PORT for in-compose cloudflared
```

**Additional Steps**:
1. Uncomment the `cloudflared` service in `docker-compose.yml`
2. Configure Cloudflare Tunnel to point to `http://nextcloud-aio-mastercontainer:80`

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
     - **Service**: `http://nextcloud-aio-mastercontainer:80` (**Use HTTP with port 80**)
   
   > [!IMPORTANT]
   > **For in-compose cloudflared, use port 80**: `http://nextcloud-aio-mastercontainer:80`
   > 
   > - DO NOT set APACHE_PORT in your .env file for in-compose cloudflared
   > - APACHE_PORT is ONLY for external reverse proxies running on the host
   > - Port 80 is the correct port for in-compose tunnel services
   > - Cloudflare will handle HTTPS for external connections

4. **Update `.env`** (DO NOT set APACHE_PORT):
   ```env
   CF_TUNNEL_TOKEN=eyJhIjoiXXXXX...
   SKIP_DOMAIN_VALIDATION=true
   # DO NOT set APACHE_PORT for in-compose cloudflared
   ```

5. **Uncomment cloudflared service** in `docker-compose.yml`:
   ```yaml
   cloudflared:
     image: cloudflare/cloudflared:latest
     restart: always
     container_name: nextcloud-aio-cloudflared
     networks:
       - nextcloud-aio
     command: tunnel --no-autoupdate run
     environment:
       TUNNEL_TOKEN: ${CF_TUNNEL_TOKEN}
     depends_on:
       - nextcloud-aio-mastercontainer
   ```

6. **Start the services**:
   ```bash
   docker compose -f docker-compose.yml up -d
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
docker compose -f docker-compose.yml ps redis

# View Valkey logs
docker compose -f docker-compose.yml logs redis

# Test Valkey connection (from within container)
docker compose -f docker-compose.yml exec redis valkey-cli PING
# Expected output: PONG

# Test with password (using environment variable for security)
docker compose -f docker-compose.yml exec redis sh -c 'REDISCLI_AUTH="$REDIS_HOST_PASSWORD" valkey-cli PING'
# Expected output: PONG
```

**Note:** Using `REDISCLI_AUTH` environment variable instead of `-a` flag prevents password exposure in process lists.

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
docker compose -f docker-compose.yml config

# Check environment variables
docker compose -f docker-compose.yml config | grep -E "BIND_ADDR|REDIS_HOST_PASSWORD|SKIP_DOMAIN"
```

### Build and Health Checks

```bash
# Build Valkey image
docker compose -f docker-compose.yml build redis

# Start services
docker compose -f docker-compose.yml up -d

# Wait 60 seconds for services to initialize
sleep 60

# Check health status
docker compose -f docker-compose.yml ps

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
docker compose -f docker-compose.yml exec redis valkey-cli PING

# Test PING with password
docker compose -f docker-compose.yml exec redis valkey-cli -a "${REDIS_HOST_PASSWORD}" PING

# Check Valkey info
docker compose -f docker-compose.yml exec redis valkey-cli -a "${REDIS_HOST_PASSWORD}" INFO server
```

### Cloudflare Tunnel Validation

```bash
# Check tunnel status
docker compose -f docker-compose.yml logs cloudflared

# Look for successful connection message:
# "Connection <UUID> registered"
# "Started tunnel connection"

# Test external access
curl -I https://cloud.example.com
# Should return Nextcloud headers
```

### Complete Validation Checklist

- [ ] Valkey container is healthy (`docker compose -f docker-compose.yml ps`)
- [ ] Nextcloud AIO mastercontainer is healthy
- [ ] Valkey responds to PING command
- [ ] Can access admin interface on configured port
- [ ] LAN access works (if BIND_ADDR=0.0.0.0)
- [ ] LAN access blocked (if BIND_ADDR=127.0.0.1)
- [ ] Cloudflare Tunnel connected (if enabled)
- [ ] External domain resolves to Nextcloud (if tunnel enabled)
- [ ] No secrets in `.env` file committed to git

## Troubleshooting

### Valkey Container Won't Start (Windows Users)

**Symptom**: Container restarts endlessly with error `exec /start.sh: no such file or directory`

**Cause**: Git on Windows may convert LF line endings to CRLF, which breaks shell scripts in Linux containers.

**Solutions**:
1. **Recommended**: Ensure Git uses LF line endings:
   ```bash
   # In the repository directory, run:
   git config core.autocrlf false
   git rm --cached -r .
   git reset --hard
   ```

2. **Alternative**: Rebuild the image after fixing line endings:
   ```bash
   # Convert scripts to LF endings (Git Bash or WSL)
   dos2unix Containers/valkey/start.sh Containers/valkey/healthcheck.sh
   
   # Rebuild the image
   docker compose -f docker-compose.yml build redis --no-cache
   docker compose -f docker-compose.yml up -d
   ```

3. **Verify line endings** in the repository:
   ```bash
   # Should show LF, not CRLF
   file Containers/valkey/start.sh
   ```

### Valkey Container Won't Start (General)

**Symptom**: Valkey container exits immediately or restarts constantly.

**Solutions**:
1. Check logs: `docker compose -f docker-compose.yml logs redis`
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

**Symptom**: Container shows as "unhealthy" in `docker compose -f docker-compose.yml ps`.

**Solutions**:
1. Check if password is set correctly:
   ```bash
   docker compose -f docker-compose.yml exec redis valkey-cli -a "your-password" PING
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

### Cloudflare Tunnel TLS Errors

**Symptom**: Cloudflare Tunnel logs show `remote error: tls: internal error` or `Unable to reach the origin service`.

**Cause**: Multiple possible causes when using HTTPS origin:
1. Mastercontainer not fully started/healthy yet
2. Self-signed certificate causing TLS handshake failures
3. TLS version or cipher mismatch
4. Incorrect service name or port

**Solutions**:

1. **RECOMMENDED**: Change to HTTP origin (simplest fix):
   - In Cloudflare Zero Trust dashboard, edit your tunnel's public hostname
   - Change service URL to `http://nextcloud-aio-mastercontainer:80`
   - Remove or set `No TLS Verify` to OFF (not needed for HTTP)
   - Save and wait 30-60 seconds for changes to propagate
   - Cloudflare still serves HTTPS to end users; only internal connection uses HTTP

2. **Verify mastercontainer is running and healthy**:
   ```bash
   # Check if mastercontainer is running
   docker compose -f docker-compose.yml ps nextcloud-aio-mastercontainer
   
   # Check mastercontainer logs for startup completion
   docker compose -f docker-compose.yml logs nextcloud-aio-mastercontainer | tail -50
   
   # Test if port 80 is responding inside Docker network
   docker compose -f docker-compose.yml exec cloudflared wget -O- http://nextcloud-aio-mastercontainer:80 2>&1 | head
   
   # Test if port 8443 is responding (if using HTTPS)
   docker compose -f docker-compose.yml exec cloudflared wget --no-check-certificate -O- https://nextcloud-aio-mastercontainer:8443 2>&1 | head
   ```

3. **If using HTTPS with noTLSVerify and still failing**, check for these issues:
   
   a. Verify the mastercontainer HTTPS service is actually listening:
   ```bash
   # From inside cloudflared container
   docker compose -f docker-compose.yml exec cloudflared nc -zv nextcloud-aio-mastercontainer 8443
   # Should show: succeeded!
   ```
   
   b. Check if it's a TLS protocol version issue:
   ```bash
   # Test TLS handshake from cloudflared container
   docker compose -f docker-compose.yml exec cloudflared sh -c "echo | openssl s_client -connect nextcloud-aio-mastercontainer:8443 2>&1 | head -20"
   ```
   
   c. The error "tls: internal error" often means the server closed the connection during handshake.
      This can happen if:
      - Mastercontainer is still starting up (wait 2-3 minutes after start)
      - Too many concurrent connection attempts (restart both services)
      - Certificate chain issues

4. **Create a proper tunnel config file** for HTTPS with noTLSVerify:
   
   Create `cloudflared-config.yml`:
   ```yaml
   tunnel: <your-tunnel-id>
   credentials-file: /etc/cloudflared/credentials.json
   
   ingress:
     - hostname: nxt.dohwvchd.info
       service: https://nextcloud-aio-mastercontainer:8443
       originRequest:
         noTLSVerify: true
         # Add these for better compatibility with self-signed certs
         disableChunkedEncoding: false
         http2Origin: true
     - hostname: chat.dohwvchd.info  
       service: https://nextcloud-aio-mastercontainer:8443
       originRequest:
         noTLSVerify: true
         disableChunkedEncoding: false
         http2Origin: true
     - service: http_status:404
   ```
   
   Update docker-compose.yml cloudflared section:
   ```yaml
   cloudflared:
     image: cloudflare/cloudflared:latest
     restart: always
     container_name: nextcloud-aio-cloudflared
     networks:
       - nextcloud-aio
     command: tunnel --config /etc/cloudflared/config.yml run
     volumes:
       - ./cloudflared-config.yml:/etc/cloudflared/config.yml:ro
       - ./cloudflared-credentials.json:/etc/cloudflared/credentials.json:ro
     depends_on:
       - nextcloud-aio-mastercontainer
   ```

5. **Restart in the correct order**:
   ```bash
   # Stop everything
   docker compose -f docker-compose.yml down
   
   # Start mastercontainer first and wait for it to be fully ready
   docker compose -f docker-compose.yml up -d nextcloud-aio-mastercontainer
   
   # Wait 2-3 minutes and check it's healthy
   docker compose -f docker-compose.yml ps nextcloud-aio-mastercontainer
   
   # Then start cloudflared
   docker compose -f docker-compose.yml up -d cloudflared
   
   # Monitor logs
   docker compose -f docker-compose.yml logs -f cloudflared
   ```

6. **Check for port conflicts or network issues**:
   ```bash
   # Verify both containers are on the same network
   docker network inspect nextcloud-aio
   
   # Both containers should be listed under "Containers"
   ```

### Cloudflare Tunnel Redirect Loop (ERR_TOO_MANY_REDIRECTS)

**Symptom**: Browser shows "ERR_TOO_MANY_REDIRECTS" or "redirected you too many times" when accessing through Cloudflare Tunnel.

**Cause**: Incorrect use of APACHE_PORT with in-compose cloudflared.

**Solution**:

> [!IMPORTANT]
> **APACHE_PORT should NOT be used with in-compose cloudflared!**
> 
> - APACHE_PORT is ONLY for **external reverse proxies** running on the host machine
> - For in-compose cloudflared, use port 80 and DO NOT set APACHE_PORT

**For in-compose cloudflared (CORRECT configuration)**:

1. **Remove APACHE_PORT from your `.env` file**:
   ```env
   # DO NOT set APACHE_PORT for in-compose cloudflared
   # APACHE_PORT=11000  <- REMOVE THIS LINE
   SKIP_DOMAIN_VALIDATION=true
   ```

2. **Configure Cloudflare Tunnel to use port 80**:
   - In Cloudflare Zero Trust dashboard, edit your tunnel's public hostname
   - Set service URL to `http://nextcloud-aio-mastercontainer:80`

3. **Restart the services**:
   ```bash
   docker compose -f docker-compose.yml down
   docker compose -f docker-compose.yml up -d
   ```

**For external reverse proxy (e.g., Nginx/Caddy on host)**:

Only use APACHE_PORT if you're running a reverse proxy **outside** of Docker Compose:

1. **Set APACHE_PORT in `.env`**:
   ```env
   APACHE_PORT=11000
   APACHE_IP_BINDING=127.0.0.1
   ```

2. **Your external reverse proxy** connects to `http://localhost:11000`

3. **Do NOT use in-compose cloudflared** - use your external reverse proxy instead

**Why this distinction matters**:
- In-compose cloudflared can access port 80 directly via Docker network
- External reverse proxies need the special APACHE_PORT (11000) exposed on the host
- Mixing these configurations causes connection refused or redirect loops

### Cloudflare Tunnel Connection Refused (Port 11000)

**Symptom**: Tunnel logs show `dial tcp X.X.X.X:11000: connect: connection refused`

**Cause**: APACHE_PORT is set in .env but shouldn't be used with in-compose cloudflared.

**Solution**:

1. **Remove APACHE_PORT from `.env`**:
   ```bash
   # Edit your .env file and remove or comment out these lines:
   # APACHE_PORT=11000
   # APACHE_IP_BINDING=127.0.0.1
   ```

2. **Update Cloudflare Tunnel to use port 80**:
   - In Cloudflare Zero Trust dashboard, edit your tunnel
   - Change service from `http://nextcloud-aio-mastercontainer:11000`
   - To: `http://nextcloud-aio-mastercontainer:80`

3. **Restart everything**:
   ```bash
   docker compose -f docker-compose.yml down
   docker compose -f docker-compose.yml up -d
   ```

### Local Access SSL/Certificate Errors (EXPECTED BEHAVIOR)

**Symptom**: Accessing `http://localhost:8082` or `https://localhost:7443` shows SSL/TLS certificate errors.

**This is NORMAL and EXPECTED**:

1. **HTTP redirects to HTTPS**: Nextcloud AIO automatically redirects HTTP requests to HTTPS
2. **Self-signed certificates**: Nextcloud AIO uses self-signed SSL certificates by default
3. **Browser warnings**: Your browser/curl will show security warnings

**Solutions**:

1. **For browsers**: Accept the security exception or certificate warning
   - Chrome: Click "Advanced" → "Proceed to localhost (unsafe)"
   - Firefox: Click "Advanced" → "Accept the Risk and Continue"
   - Edge: Click "Advanced" → "Continue to localhost (unsafe)"

2. **For curl/API testing**: Use the `-k` flag to skip certificate verification
   ```bash
   # HTTP will redirect to HTTPS
   curl -Lk http://localhost:8082
   
   # Direct HTTPS access (skip verification)
   curl -k https://localhost:7443
   
   # See the redirect in action
   curl -v http://localhost:8082
   ```

3. **For production**: Configure a proper domain with valid SSL certificates
   - Use Let's Encrypt via Nextcloud AIO's built-in support
   - Or use Cloudflare Tunnel (which provides valid certificates)

**Why this happens**:
- Nextcloud AIO enforces HTTPS for security
- Self-signed certificates are used by default for ease of setup
- This is intentional and protects your data

### Local Access SSL Protocol Error (Configuration Issue)

**Symptom**: Cannot access Nextcloud on custom host ports (e.g., 8082, 7443, 8083) - different SSL error like SEC_E_INTERNAL_ERROR or connection issues.

**Cause**: When APACHE_PORT is set incorrectly, it changes how the mastercontainer listens for connections, breaking the normal port mappings.

**Solution**:

1. **Remove APACHE_PORT from `.env`** (unless you're using an external reverse proxy):
   ```env
   # Comment out or remove:
   # APACHE_PORT=11000
   ```

2. **Restart services**:
   ```bash
   docker compose -f docker-compose.yml down
   docker compose -f docker-compose.yml up -d
   ```

3. **Access via the configured ports** (and accept the self-signed certificate):
   - HTTP: `http://localhost:8082` (redirects to HTTPS)
   - HTTPS: `https://localhost:7443` (accept certificate warning)
   - Admin: `https://localhost:8083` (accept certificate warning)

**Note**: APACHE_PORT changes the internal behavior of Nextcloud AIO and is incompatible with normal direct access. Only use it if you have an external reverse proxy on the host machine.

### Cloudflare Tunnel Certificate Warning

**Symptom**: Cloudflared logs show "Cannot determine default origin certificate path" error.

**This is NORMAL**: This warning appears when using token-based authentication and can be safely ignored.

**Why it appears**:
- Cloudflared looks for a certificate file for advanced configurations
- When using `TUNNEL_TOKEN`, no certificate file is needed
- The tunnel works correctly despite this warning

**No action needed**: The warning doesn't affect functionality. Your tunnel is working if you see:
- "Starting tunnel tunnelID=..."
- "Connection registered"
- No other connection errors

### Cloudflare Tunnel Not Connecting

**Symptom**: Tunnel logs show connection errors or timeout (not TLS-related).

**Solutions**:
1. Verify tunnel token is correct in `.env`
2. Check tunnel configuration in Cloudflare dashboard
3. Ensure Nextcloud service name is correct: `nextcloud-aio-mastercontainer`
4. Check tunnel logs:
   ```bash
   docker compose -f docker-compose.yml logs cloudflared
   ```
5. Verify network connectivity:
   ```bash
   docker compose -f docker-compose.yml exec cloudflared ping -c 3 nextcloud-aio-mastercontainer
   ```

### Domain Validation Errors

**Symptom**: Nextcloud AIO shows domain validation errors.

**Solutions**:
1. Ensure `SKIP_DOMAIN_VALIDATION=true` in `.env` when using Cloudflare Tunnel
2. Restart services after changing `.env`:
   ```bash
   docker compose -f docker-compose.yml down
   docker compose -f docker-compose.yml up -d
   ```
3. Check Nextcloud trusted domains in `config.php`

### Services Not Using Updated .env Values

**Symptom**: Changes to `.env` don't take effect.

**Solutions**:
1. Recreate containers (not just restart):
   ```bash
   docker compose -f docker-compose.yml down
   docker compose -f docker-compose.yml up -d
   ```
2. For environment changes, rebuild if needed:
   ```bash
   docker compose -f docker-compose.yml up --build -d
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
docker compose -f docker-compose.yml build --build-arg VALKEY_VERSION=7.2.5 redis

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
   docker compose -f docker-compose.yml pull
   docker compose -f docker-compose.yml up -d
   ```

6. **Review container logs regularly**:
   ```bash
   docker compose -f docker-compose.yml logs --tail=100 --follow
   ```

## Support and Resources

- **Nextcloud AIO Documentation**: [https://github.com/nextcloud/all-in-one](https://github.com/nextcloud/all-in-one)
- **Valkey Documentation**: [https://valkey.io/documentation](https://valkey.io)
- **Cloudflare Tunnel Docs**: [https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- **Docker Compose Reference**: [https://docs.docker.com/compose/compose-file/](https://docs.docker.com/compose/compose-file/)

## Contributing

Found an issue or have an improvement? Please open an issue or pull request in the repository.
