# Docker Compose Setup Guide for Multiple OpenClaw Instances

This guide explains how to run multiple OpenClaw instances (e.g., chunny_1, chunny_2, chunny_3) on the same host with different ports.

## Problem Overview

When running multiple OpenClaw instances, you need unique ports for each instance. The default configuration has hardcoded ports that cause conflicts.

## Solutions Applied

### 1. Dynamic Healthcheck Port

**File:** `docker-compose.yml` (lines 62-73)

**Problem:** Healthcheck was hardcoded to check port `18789`, causing failures when using different ports.

**Solution:** Changed to use shell with environment variable expansion:

```yaml
healthcheck:
  test:
    - CMD
    - sh
    - -c
    - "node -e \"fetch('http://127.0.0.1:${OPENCLAW_GATEWAY_PORT:-18789}/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""
```

### 2. Dynamic Port Mapping

**File:** `docker-compose.yml` (lines 56-59)

**Problem:** Port mapping was `HOST_PORT:18789` (fixed container port), but the gateway binds to the port specified in `OPENCLAW_GATEWAY_PORT` environment variable.

**Solution:** Changed both host and container ports to use the same environment variable:

```yaml
ports:
  - "${OPENCLAW_GATEWAY_PORT:-18789}:${OPENCLAW_GATEWAY_PORT:-18789}"
  - "${OPENCLAW_BRIDGE_PORT:-18790}:${OPENCLAW_BRIDGE_PORT:-18790}"
  - "8000:8000"
```

### 3. Gateway Bind Address

**File:** `data/{INSTANCE_NAME}/openclaw.json` (line ~93)

**Problem:** Gateway was bound to `loopback` (127.0.0.1) inside the container, preventing Docker port mapping from working.

**Solution:** Changed bind setting from `loopback` to `lan`:

```json
"gateway": {
  "port": 19789,
  "mode": "local",
  "bind": "lan",  // Changed from "loopback"
  ...
}
```

**Valid bind values:** `auto`, `lan`, `loopback`, `custom`, `tailnet`

## How to Start Multiple Instances

### Step 1: Create Environment Files

Create `.env.chunny_1`, `.env.chunny_2`, etc. with unique ports:

```bash
# .env.chunny_1
COMPOSE_PROJECT_NAME=openclaw-chunny_1
OPENCLAW_GATEWAY_PORT=19789
OPENCLAW_BRIDGE_PORT=19780
OPENCLAW_CONFIG_DIR=./data/chunny_1
OPENCLAW_WORKSPACE_DIR=./data/chunny_1/workspace
OPENCLAW_GATEWAY_TOKEN=your_token_here
# ... other config
```

```bash
# .env.chunny_2
COMPOSE_PROJECT_NAME=openclaw-chunny_2
OPENCLAW_GATEWAY_PORT=19799
OPENCLAW_BRIDGE_PORT=19790
OPENCLAW_CONFIG_DIR=./data/chunny_2
OPENCLAW_WORKSPACE_DIR=./data/chunny_2/workspace
OPENCLAW_GATEWAY_TOKEN=your_token_here
# ... other config
```

### Step 2: Start Instances

```bash
# Start chunny_1
docker compose -p openclaw-chunny_1 --env-file .env.chunny_1 up -d

# Start chunny_2
docker compose -p openclaw-chunny_2 --env-file .env.chunny_2 up -d
```

### Step 3: Update Gateway Bind (First Time Only)

After first start, update the bind setting in each instance's config:

```bash
# For chunny_1
sed -i 's/"bind": "loopback"/"bind": "lan"/' data/chunny_1/openclaw.json
docker compose -p openclaw-chunny_1 restart

# For chunny_2
sed -i 's/"bind": "loopback"/"bind": "lan"/' data/chunny_2/openclaw.json
docker compose -p openclaw-chunny_2 restart
```

## Access URLs

| Instance | Gateway URL | Chat UI |
|----------|-------------|---------|
| chunny_1 | http://127.0.0.1:19789 | http://127.0.0.1:19789/chat?session=agent:main:main |
| chunny_2 | http://127.0.0.1:19799 | http://127.0.0.1:19799/chat?session=agent:main:main |

## Troubleshooting

### Container shows "unhealthy"

Check if the healthcheck port matches the gateway's listening port:
```bash
docker compose -p openclaw-XXX logs --tail=50 | grep "listening on"
```

### Browser shows "Unauthorized"

The gateway requires authentication via `x-openclaw-token` header. The web UI should handle this automatically.

### Nothing happens when accessing chat URL

1. Check container is running: `docker compose -p openclaw-XXX ps`
2. Check logs: `docker compose -p openclaw-XXX logs --tail=50`
3. Verify bind address is `lan` not `loopback`
4. Verify port mapping uses same port for both sides: `PORT:PORT`

## Management Commands

```bash
# View status of all instances
docker compose -p openclaw-chunny_1 ps
docker compose -p openclaw-chunny_2 ps

# View logs
docker compose -p openclaw-chunny_1 logs -f

# Stop an instance
docker compose -p openclaw-chunny_1 down

# Restart an instance
docker compose -p openclaw-chunny_1 restart
```

## File Structure

```
openclaw/
├── docker-compose.yml
├── .env.chunny_1
├── .env.chunny_2
└── data/
    ├── chunny_1/
    │   ├── openclaw.json       # Gateway config (bind: "lan")
    │   ├── workspace/
    │   └── canvas/
    │       └── index.html
    └── chunny_2/
        ├── openclaw.json
        ├── workspace/
        └── canvas/
```
