#!/bin/sh
set -eu

APP_DIR="${APP_DIR:-/srv/app}"
REPO_URL="${REPO_URL:-https://github.com/stefanelul2000/ethical-hacking-apps.git}"
REPO_BRANCH="${REPO_BRANCH:-master}"
PROJECT_SUBDIR="${PROJECT_SUBDIR:-rest-api}"

mkdir -p "$(dirname "$APP_DIR")"

determine_target_branch() {
  remote_url="$1"
  requested_branch="$2"
  branch=""

  if [ -n "$requested_branch" ]; then
    if git ls-remote --exit-code --heads "$remote_url" "$requested_branch" >/dev/null 2>&1; then
      branch="$requested_branch"
    else
      echo "Requested branch '${requested_branch}' not found on remote ${remote_url}. Falling back to the remote default." >&2
    fi
  fi

  if [ -z "$branch" ]; then
    branch="$(git ls-remote --symref "$remote_url" HEAD 2>/dev/null | awk '/^ref:/{sub(\"refs/heads/\",\"\",$2); print $2; exit}')"
  fi

  if [ -z "$branch" ]; then
    if git ls-remote --exit-code --heads "$remote_url" main >/dev/null 2>&1; then
      branch="main"
    elif git ls-remote --exit-code --heads "$remote_url" master >/dev/null 2>&1; then
      branch="master"
    else
      branch="$(git ls-remote "$remote_url" 2>/dev/null | awk '/refs\/heads\//{sub(\"refs/heads/\",\"\",$2); print $2; exit}')"
    fi
  fi

  if [ -z "$branch" ]; then
    echo "Unable to determine a branch to checkout from ${remote_url}" >&2
    exit 1
  fi

  echo "$branch"
}

TARGET_BRANCH=""

if [ ! -d "$APP_DIR/.git" ]; then
  TARGET_BRANCH="$(determine_target_branch "$REPO_URL" "$REPO_BRANCH")"
  echo "Cloning ${REPO_URL} (branch: ${TARGET_BRANCH}) into ${APP_DIR}..."
  if [ -d "$APP_DIR" ]; then
    # Clear mount contents while keeping the directory for Docker volumes
    find "$APP_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  else
    mkdir -p "$APP_DIR"
  fi
  git clone --depth 1 --branch "$TARGET_BRANCH" "$REPO_URL" "$APP_DIR"
else
  git config --global --add safe.directory "$APP_DIR" || true

  if git -C "$APP_DIR" remote get-url origin >/dev/null 2>&1; then
    git -C "$APP_DIR" remote set-url origin "$REPO_URL"
  else
    git -C "$APP_DIR" remote add origin "$REPO_URL"
  fi

  REMOTE_URL="$(git -C "$APP_DIR" remote get-url origin)"
  TARGET_BRANCH="$(determine_target_branch "$REMOTE_URL" "$REPO_BRANCH")"

  echo "Synchronizing branch ${TARGET_BRANCH}..."
  if ! git -C "$APP_DIR" fetch origin "${TARGET_BRANCH}"; then
    echo "Unable to fetch branch '${TARGET_BRANCH}' from remote ${REMOTE_URL}" >&2
    exit 1
  fi

  git -C "$APP_DIR" checkout -B "${TARGET_BRANCH}" "origin/${TARGET_BRANCH}"
  git -C "$APP_DIR" reset --hard "origin/${TARGET_BRANCH}"
  git -C "$APP_DIR" clean -fdx
fi

git config --global --add safe.directory "$APP_DIR" || true

cd "$APP_DIR"

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
