# Compose Examples

This directory holds `docker-compose.yml` for running all prod/dev variants locally. Each service uses the baked defaults from its image tag (`rest-api-prod/dev`, `ai-mcp-client-prod/dev`, `ai-mcp-server-prod/dev`, `iris-prod/dev`). Override via environment if needed.

## Services, Environment, and Healthchecks

- `rest-api-*`  
  - `SERVICE_VARIANT=rest-api`  
  - `REPO_BRANCH` (`master` for prod, `arh` for dev)  
  - `UPLOAD_*` throttling/auth vars  
  - Ports: prod `8000:8000`, dev `8005:8000`
  - Healthcheck: HTTP `GET /health` via inline python3

- `ai-mcp-client-*`  
  - `SERVICE_VARIANT=mcp-client`  
  - `REPO_BRANCH` (`master`/`arh`)  
  - `MCP_ADMIN_USER`, `MCP_ADMIN_PASS`, `GROQ_MODEL`, `GROQ_API_KEY`  
  - Ports: prod `8001:8000`, dev `8002:8000`
  - Healthcheck: HTTP `GET /health` via inline python3

- `ai-mcp-server-*`  
  - `SERVICE_VARIANT=mcp-server`  
  - `REPO_BRANCH` (`master`/`arh`)  
  - `ENABLE_MCP_COMMAND_TOOL` (keep `0` for safety)  
  - Ports: prod `8003:8001`, dev `8004:8001`
  - Healthcheck: TCP connect to `MCP_SERVER_PORT` (python3 socket)

- `iris-*`  
  - `SERVICE_VARIANT=iris`  
  - `REPO_BRANCH` (`master`/`arh`)  
  - Working dir `ai/iris`, runs `uvicorn iris:iris`  
  - Ports: prod `8101:8001`, dev `8102:8001`
  - Healthcheck: HTTP `GET /` via inline python3

## Volume Mapping (optional)

To persist the cloned repo on the host or inspect it, you can bind-mount `/srv/app`:

```yaml
    volumes:
      - /path/on/host/ethical-hacking-apps:/srv/app
```

Add this to any service definition to keep the working tree between container runs.

## Usage

From this folder:

```bash
docker compose up -d          # start all services
docker compose logs -f        # stream logs
```

Update secrets (e.g., `GROQ_API_KEY`, `MCP_ADMIN_*`, upload credentials) before running.
