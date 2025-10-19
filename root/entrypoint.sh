#!/bin/sh
set -eu

APP_DIR="${APP_DIR:-/srv/app}"
REPO_URL="${REPO_URL:-https://github.com/stefanelul2000/ethical-hacking-apps.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
PROJECT_SUBDIR="${PROJECT_SUBDIR:-rest-api}"

mkdir -p "$APP_DIR"

if [ ! -d "$APP_DIR/.git" ]; then
  echo "Bootstrapping git repository in ${APP_DIR}..."
  git init "$APP_DIR"
fi

git config --global --add safe.directory "$APP_DIR" || true

if git -C "$APP_DIR" remote get-url origin >/dev/null 2>&1; then
  git -C "$APP_DIR" remote set-url origin "$REPO_URL"
else
  git -C "$APP_DIR" remote add origin "$REPO_URL"
fi

cd "$APP_DIR"

TARGET_BRANCH=""

if [ -n "$REPO_BRANCH" ]; then
  if git ls-remote --exit-code --heads origin "$REPO_BRANCH" >/dev/null 2>&1; then
    TARGET_BRANCH="$REPO_BRANCH"
  else
    echo "Requested branch '${REPO_BRANCH}' not found on remote, discovering default branch..."
  fi
fi

if [ -z "$TARGET_BRANCH" ]; then
  TARGET_BRANCH="$(git ls-remote --symref origin HEAD 2>/dev/null | awk '/^ref:/{sub(\"refs/heads/\",\"\",$2); print $2; exit}')"
fi

if [ -z "$TARGET_BRANCH" ]; then
  echo "Falling back to 'main' branch"
  TARGET_BRANCH="main"
fi

echo "Synchronizing branch ${TARGET_BRANCH}..."
if ! git fetch origin "${TARGET_BRANCH}"; then
  echo "Failed to fetch branch '${TARGET_BRANCH}', falling back to remote default..."
  FALLBACK_BRANCH="$(git ls-remote --symref origin HEAD 2>/dev/null | awk '/^ref:/{sub(\"refs/heads/\",\"\",$2); print $2; exit}')"
  if [ -z "$FALLBACK_BRANCH" ]; then
    echo "Remote default branch unknown, falling back to 'master'..."
    FALLBACK_BRANCH="master"
  fi
  TARGET_BRANCH="$FALLBACK_BRANCH"
  if ! git fetch origin "${TARGET_BRANCH}"; then
    echo "Unable to fetch branch '${TARGET_BRANCH}' from remote" >&2
    exit 1
  fi
fi

git checkout -B "${TARGET_BRANCH}" "origin/${TARGET_BRANCH}"
git reset --hard "origin/${TARGET_BRANCH}"

git clean -fdx

if [ -n "$PROJECT_SUBDIR" ]; then
  PROJECT_DIR="${APP_DIR%/}/${PROJECT_SUBDIR#/}"
else
  PROJECT_DIR="$APP_DIR"
fi

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Project directory ${PROJECT_DIR} not found" >&2
  exit 1
fi

cd "$PROJECT_DIR"

if [ -f ".python-version" ]; then
  PY_SPEC="$(tr -d '[:space:]' < .python-version)"
elif [ -f "${APP_DIR}/.python-version" ]; then
  PY_SPEC="$(tr -d '[:space:]' < "${APP_DIR}/.python-version")"
else
  PY_SPEC="${UV_PYTHON_SPEC:-python3.10}"
fi

if [ -f "uv.lock" ] || [ -f "pyproject.toml" ]; then
  if [ -f "uv.lock" ]; then
    uv sync --python "$PY_SPEC" --frozen
  else
    uv sync --python "$PY_SPEC"
  fi
elif [ -f "requirements.txt" ]; then
  uv venv --python "$PY_SPEC"
  uv pip install --python "$PY_SPEC" -r requirements.txt
fi

UVICORN_APP="${UVICORN_APP:-a:app}"
UVICORN_HOST="${UVICORN_HOST:-0.0.0.0}"
UVICORN_PORT="${UVICORN_PORT:-8000}"
UVICORN_RELOAD="${UVICORN_RELOAD:-1}"

set -- uv run --python "$PY_SPEC" uvicorn "$UVICORN_APP" --host "$UVICORN_HOST" --port "$UVICORN_PORT"
if [ "$UVICORN_RELOAD" != "0" ]; then
  set -- "$@" --reload
fi

exec "$@"
