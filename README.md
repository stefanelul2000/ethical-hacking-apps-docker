# Ethical Hacking Apps – Docker Stack

This repo builds the container images that wrap the upstream project at
`https://github.com/stefanelul2000/ethical-hacking-apps`. The entrypoint can
launch three different apps depending on the `SERVICE_VARIANT` environment
variable:

| Variant      | Repo branch default | Entry point                            |
|--------------|--------------------|----------------------------------------|
| `rest-api`   | `master` / `arh`   | `uvicorn main:app`                     |
| `mcp-client` | `master`           | `uvicorn agents.mcp_client:app`        |
| `mcp-server` | `master`           | `python agents/mcp_server.py`          |
| `iris`       | `master` / `arh`   | `uvicorn iris:iris` (cwd `ai/iris`)    |

You can override `REPO_BRANCH` if you want to pin a different revision.

## Local development with Docker Compose

The provided `docker-compose.yml` spins up five services:

- `rest-api-prod` / `rest-api-dev` – REST API on `master` / `arh`.
- `ai-mcp-client-prod` / `ai-mcp-client-dev` – MCP client on `master` / `arh`.
- `ai-mcp-server-prod` / `ai-mcp-server-dev` – MCP server on `master` / `arh`.
- `iris-prod` / `iris-dev` – Iris FastAPI service running from `ai/iris` (`master` / `arh`; internal port 8001, mapped to 8101 by default).

Environment variables set in the compose file ensure the entrypoint runs the
correct variant. Update secrets such as `GROQ_API_KEY`, `MCP_ADMIN_*`, and the
upload credentials before running:

```bash
docker compose up -d
```

Refer to `docker-compose.yml` for the exact environment variables used in each
service and adjust them for your deployment.

If you prefer to run a single container manually:

```bash
docker run --rm \
  -e SERVICE_VARIANT=mcp-client \
  -e REPO_BRANCH=master \
  -p 8001:8000 \
  ghcr.io/stefanelul2000/ethical-hacking-apps-docker:ai-mcp-client-master
```

The entrypoint clones the requested branch, installs dependencies via `uv`, and
activates `.venv` before launching the selected app, so the containers always
run against the latest code from the upstream repo.
