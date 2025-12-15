# Windows WSL2 Deployment Guide

**For Windows Users Running Docker Desktop with WSL2**

---

## Common Issues on Windows/WSL2

### Issue 1: Line Ending Problems

**Symptom:** Valkey/Redis container restarts endlessly with error:
```
exec /start.sh: no such file or directory
```

**Cause:** Git on Windows converts LF line endings to CRLF, breaking shell scripts in Linux containers.

### Issue 2: Docker Socket Path

**Symptom:** Containers can't access Docker socket

**Cause:** WSL2 uses different path for Docker socket

### Issue 3: Volume Mount Paths

**Symptom:** Data directory mounting fails

**Cause:** Windows path format incompatible with Docker

---

## Complete Fix for WSL2

### Step 1: Configure Git for Linux Line Endings

**CRITICAL: Run these commands BEFORE cloning or pulling the repository**

```bash
# Configure Git to NOT convert line endings
git config --global core.autocrlf false
git config --global core.eol lf

# Verify the configuration
git config --get core.autocrlf  # Should show: false
git config --get core.eol       # Should show: lf
```

### Step 2: Clean and Re-clone (If Already Cloned)

**Option A: If you already cloned the repository**

```bash
# Navigate to your repository
cd /path/to/nextcloud-aio

# Remove all files but keep .git
git rm --cached -r .
git reset --hard

# Force checkout with LF endings
git rm -rf --cached .
git config core.autocrlf false
git reset --hard HEAD
```

**Option B: Fresh clone (RECOMMENDED)**

```bash
# Delete the old repository
cd ~
rm -rf nextcloud-aio

# Configure Git first
git config --global core.autocrlf false
git config --global core.eol lf

# Clone fresh
git clone https://github.com/jp-pelegrino/nextcloud-aio.git
cd nextcloud-aio

# Verify line endings
file Containers/valkey/start.sh
# Should show: "POSIX shell script, ASCII text executable"
# Should NOT show "CRLF"
```

### Step 3: Verify Line Endings

```bash
cd /path/to/nextcloud-aio

# Check start.sh
od -c Containers/valkey/start.sh | head -5
# Should show \n (LF), NOT \r\n (CRLF)

# Check healthcheck.sh
od -c Containers/valkey/healthcheck.sh | head -5
# Should show \n (LF), NOT \r\n (CRLF)

# Alternative check with file command
file Containers/valkey/*.sh
# Should show "ASCII text executable" without "CRLF"
```

### Step 4: Create WSL2-Specific .env File

```bash
cd /path/to/nextcloud-aio

# Copy example
cp .env.example .env

# Edit with nano or vim (NOT Windows Notepad++)
nano .env
```

**IMPORTANT:** Use a Linux text editor (nano, vim, vi) NOT Windows Notepad or Notepad++

**WSL2-Specific .env Configuration:**

```env
# Network binding
BIND_ADDR=0.0.0.0

# Ports (standard or custom)
HTTP_HOST_PORT=8082
HTTPS_HOST_PORT=7443
ADMIN_HOST_PORT=8083

# CRITICAL: Use WSL2 paths for data directory
# Format: /mnt/c/path/to/folder (for C: drive)
# Format: /mnt/d/path/to/folder (for D: drive)
NEXTCLOUD_DATADIR=/mnt/d/ncdata/hosted

# Docker socket path for WSL2
HOST_DOCKER_SOCK=/var/run/docker.sock

# Redis password
REDIS_HOST_PASSWORD=your-strong-password-here

# Skip domain validation for Cloudflare
SKIP_DOMAIN_VALIDATION=true

# Other settings
AIO_VERSION=latest
RESTART_POLICY=always
VALKEY_IMAGE=nextcloud-aio-valkey:local
```

**Path Conversion Examples:**

| Windows Path | WSL2 Path |
|-------------|-----------|
| `C:\Users\MyUser\data` | `/mnt/c/Users/MyUser/data` |
| `D:\ncdata\docker` | `/mnt/d/ncdata/docker` |
| `E:\nextcloud` | `/mnt/e/nextcloud` |

### Step 5: Rebuild Valkey Image with Correct Line Endings

```bash
cd /path/to/nextcloud-aio

# Clean any old builds
docker compose -f docker-compose.yml down -v
docker rmi nextcloud-aio-valkey:local 2>/dev/null || true

# Rebuild from scratch
docker compose -f docker-compose.yml build redis --no-cache

# Verify the build succeeded
docker images | grep valkey
```

### Step 6: Start the Deployment

```bash
cd /path/to/nextcloud-aio

# Start all services
docker compose -f docker-compose.yml up -d

# Wait 30 seconds for startup
sleep 30

# Check status
docker compose -f docker-compose.yml ps
```

**Expected Output:**
```
NAME                            STATUS
nextcloud-aio-mastercontainer   Up X seconds (healthy)
nextcloud-aio-redis             Up X seconds (healthy)
```

### Step 7: Verify Valkey is Working

```bash
# Test PING command
docker compose -f docker-compose.yml exec redis sh -c 'REDISCLI_AUTH="your-strong-password-here" valkey-cli PING'

# Should return: PONG
```

**If you get "PONG", Valkey is working correctly!**

---

## Troubleshooting WSL2 Issues

### Issue: "exec /start.sh: no such file or directory"

**Diagnosis:**
```bash
# Check if file exists in container
docker compose -f docker-compose.yml exec redis ls -la /start.sh

# Check line endings
docker compose -f docker-compose.yml exec redis od -c /start.sh | head -3
```

**Fix:**
```bash
# 1. Stop containers
docker compose -f docker-compose.yml down

# 2. Fix Git configuration
git config core.autocrlf false
git config core.eol lf

# 3. Reset files
git rm --cached -r .
git reset --hard HEAD

# 4. Rebuild
docker compose -f docker-compose.yml build redis --no-cache

# 5. Start again
docker compose -f docker-compose.yml up -d
```

### Issue: Container Keeps Restarting

**Check logs:**
```bash
docker compose -f docker-compose.yml logs redis --tail 50
```

**Common Causes:**

1. **CRLF line endings** - See fix above
2. **Missing password** - Ensure `REDIS_HOST_PASSWORD` is set in .env
3. **Permission issues** - Check file permissions:
   ```bash
   ls -la Containers/valkey/*.sh
   # Should be -rwxr-xr-x (executable)
   ```

### Issue: Cannot Access from Windows

**Symptom:** Can't access http://localhost:8082 from Windows browser

**Fix:**

Check BIND_ADDR in .env:
```env
# For WSL2, use 0.0.0.0 to allow Windows to access
BIND_ADDR=0.0.0.0

# NOT 127.0.0.1 (that only works inside WSL2)
```

Then access from Windows using:
- `http://localhost:8082` (HTTP)
- `https://localhost:8083` (Admin)
- `https://localhost:7443` (HTTPS)

### Issue: Data Directory Not Found

**Symptom:** Error about NEXTCLOUD_DATADIR not existing

**Fix:**

```bash
# Create the directory in WSL2 format
mkdir -p /mnt/d/ncdata/hosted

# Verify it exists
ls -la /mnt/d/ncdata/hosted

# Update .env
nano .env
# Set: NEXTCLOUD_DATADIR=/mnt/d/ncdata/hosted
```

### Issue: Docker Socket Permission Denied

**Symptom:** Cannot access Docker socket

**Fix:**

```bash
# Check Docker socket exists
ls -la /var/run/docker.sock

# Should show: srw-rw---- 1 root docker

# Add your user to docker group (if not already)
sudo usermod -aG docker $USER

# Log out and back in, or:
newgrp docker

# Test Docker access
docker ps
```

---

## WSL2-Specific Best Practices

### 1. Use WSL2 Terminal, Not PowerShell

❌ **Don't use:**
- Windows PowerShell
- Windows Command Prompt
- Git Bash

✅ **Do use:**
- WSL2 Ubuntu terminal
- Windows Terminal (WSL2 tab)
- Any Linux distribution in WSL2

### 2. Edit Files in Linux, Not Windows

❌ **Don't use:**
- Windows Notepad
- Notepad++
- VS Code (Windows version, without WSL extension)

✅ **Do use:**
- `nano` in WSL2
- `vim` in WSL2
- VS Code with WSL Remote extension
- Any editor running inside WSL2

### 3. Use Linux Path Format

❌ **Wrong:**
```env
NEXTCLOUD_DATADIR=D:\ncdata\hosted
```

✅ **Correct:**
```env
NEXTCLOUD_DATADIR=/mnt/d/ncdata/hosted
```

### 4. Clone Repository in WSL2 Filesystem

❌ **Wrong:**
```bash
# Cloning to /mnt/c (Windows filesystem)
cd /mnt/c/Users/YourName
git clone ...
```

✅ **Correct:**
```bash
# Cloning to WSL2 home directory
cd ~
git clone ...
```

**Why:** WSL2 filesystem is much faster than accessing Windows filesystem through /mnt

---

## Complete WSL2 Setup Checklist

- [ ] Git configured: `core.autocrlf=false` and `core.eol=lf`
- [ ] Repository cloned/reset with LF line endings
- [ ] Verified line endings: `file Containers/valkey/start.sh` shows no CRLF
- [ ] .env file created using Linux text editor (nano/vim)
- [ ] Paths in .env use WSL2 format (`/mnt/d/...` not `D:\...`)
- [ ] BIND_ADDR set to `0.0.0.0` for Windows access
- [ ] Data directories created with `mkdir -p`
- [ ] User added to docker group
- [ ] Valkey image rebuilt with `--no-cache`
- [ ] Containers started and showing as healthy
- [ ] Valkey PING test returns PONG

---

## Quick Recovery Script

Save this as `wsl2-fix.sh` and run it:

```bash
#!/bin/bash

echo "WSL2 Nextcloud AIO Recovery Script"
echo "=================================="

# Step 1: Configure Git
echo "Configuring Git for Linux line endings..."
git config core.autocrlf false
git config core.eol lf

# Step 2: Reset repository
echo "Resetting repository files..."
git rm --cached -r . 2>/dev/null || true
git reset --hard HEAD

# Step 3: Verify line endings
echo "Verifying line endings..."
if file Containers/valkey/start.sh | grep -q "CRLF"; then
    echo "ERROR: Still have CRLF line endings!"
    echo "You may need to delete and re-clone the repository"
    exit 1
else
    echo "✓ Line endings correct (LF)"
fi

# Step 4: Stop and clean
echo "Stopping containers..."
docker compose -f docker-compose.yml down -v

# Step 5: Rebuild
echo "Rebuilding Valkey image..."
docker compose -f docker-compose.yml build redis --no-cache

# Step 6: Start
echo "Starting services..."
docker compose -f docker-compose.yml up -d

# Step 7: Wait and check
echo "Waiting for services to start..."
sleep 30

echo ""
echo "Checking status..."
docker compose -f docker-compose.yml ps

echo ""
echo "Testing Valkey..."
docker compose -f docker-compose.yml exec redis sh -c 'REDISCLI_AUTH="${REDIS_HOST_PASSWORD}" valkey-cli PING' || echo "Failed - check REDIS_HOST_PASSWORD in .env"

echo ""
echo "Done! Check the output above for any errors."
```

**Usage:**
```bash
chmod +x wsl2-fix.sh
./wsl2-fix.sh
```

---

## Additional Resources

- [Docker Desktop WSL 2 backend](https://docs.docker.com/desktop/wsl/)
- [WSL 2 Best Practices](https://learn.microsoft.com/en-us/windows/wsl/filesystems)
- [Git Line Endings](https://docs.github.com/en/get-started/getting-started-with-git/configuring-git-to-handle-line-endings)

---

## Still Having Issues?

If you've followed all steps and still have problems:

1. **Provide these diagnostics:**
   ```bash
   # Git configuration
   git config --get core.autocrlf
   git config --get core.eol
   
   # Line ending check
   file Containers/valkey/start.sh
   
   # Container status
   docker compose -f docker-compose.yml ps
   
   # Container logs
   docker compose -f docker-compose.yml logs redis --tail 50
   
   # File in container
   docker compose -f docker-compose.yml exec redis ls -la /start.sh 2>&1
   ```

2. **Check .env file was created in Linux:**
   ```bash
   file .env
   # Should show "ASCII text", not "ASCII text, with CRLF"
   ```

3. **Verify you're using WSL2 terminal:**
   ```bash
   uname -a
   # Should show "Linux" and "WSL2" or "microsoft"
   ```

---

**Last Updated:** 2025-12-14  
**Tested On:** Windows 11 + WSL2 Ubuntu 22.04, Docker Desktop 4.x
