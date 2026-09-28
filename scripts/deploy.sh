#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
[[ ! -f .deploy.env ]] || source .deploy.env
mkdir -p .deploy
ACTION=${1:-help}
BLOG_PORT=${BLOG_PORT:-8080}
[[ "$BLOG_PORT" =~ ^[0-9]+$ ]] && (( BLOG_PORT > 1024 && BLOG_PORT < 65536 )) || { echo 'Invalid BLOG_PORT'; exit 1; }
case "$ACTION" in
  build)
    VERSION=${2:-$(date -u +%Y%m%dT%H%M%SZ)-$(git rev-parse --short HEAD)}
    [[ "$VERSION" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || exit 1
    BLOG_IMAGE="intotw-blog:$VERSION"
    CONTEXT=$(mktemp -d)
    trap 'rm -rf "$CONTEXT"' EXIT
    rsync -a --exclude=.git --exclude=node_modules --exclude=dist --exclude=.astro --exclude='.env*' --exclude='.deploy*' --exclude=/content/ --exclude='*.backup' ./ "$CONTEXT/"
    if [[ -n ${CONTENT_SOURCE:-} ]]; then
      node scripts/prepare-deploy-posts.mjs "$CONTENT_SOURCE" "$CONTEXT/src/content/posts"
    fi
    docker buildx build --platform "${PLATFORM:-linux/amd64}" --load -t "$BLOG_IMAGE" "$CONTEXT"
    printf '%s\n' "$BLOG_IMAGE" > .deploy/image
    echo "Built $BLOG_IMAGE"
    ;;
  local)
    BLOG_IMAGE=$(cat .deploy/image)
    BLOG_PLATFORM=$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$BLOG_IMAGE")
    export BLOG_IMAGE BLOG_PORT BLOG_PLATFORM
    python3 - <<'PY'
import os
import signal
import subprocess
import sys

command = ['docker', 'compose', '-p', 'mizuki-preview', '-f', 'deploy/compose.yml',
           'up', '-d', '--wait', '--wait-timeout', '90']
process = subprocess.Popen(command, start_new_session=True)
try:
    sys.exit(process.wait(timeout=120))
except subprocess.TimeoutExpired:
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    print('Docker did not finish starting the container within 120 seconds.', file=sys.stderr)
    sys.exit(124)
PY
    curl --noproxy '*' --max-time 15 --fail --silent "http://127.0.0.1:$BLOG_PORT/" >/dev/null
    echo "Preview: http://localhost:$BLOG_PORT"
    ;;
  stop)
    BLOG_IMAGE=$(cat .deploy/image) docker compose -p mizuki-preview -f deploy/compose.yml down
    ;;
  publish|rollback)
    : "${SSH_TARGET:?Set SSH_TARGET in .deploy.env}"
    REMOTE_DIR=${REMOTE_DIR:-mizuki-deploy}
    [[ "$SSH_TARGET" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.@-]*$ ]] || exit 1
    [[ "$REMOTE_DIR" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_/-]*$ && "$REMOTE_DIR" != *..* ]] || exit 1
    ssh "$SSH_TARGET" 'docker info >/dev/null && docker compose version >/dev/null'
    ssh "$SSH_TARGET" "mkdir -p '$REMOTE_DIR'"
    if [[ "$ACTION" == publish ]]; then
      BLOG_IMAGE=$(cat .deploy/image)
      [[ $(docker image inspect --format '{{.Architecture}}' "$BLOG_IMAGE") == amd64 ]] || { echo 'VPS requires amd64: run scripts/deploy.sh build first'; exit 1; }
      docker save "$BLOG_IMAGE" | gzip | ssh "$SSH_TARGET" 'gzip -d | docker load'
      scp deploy/compose.yml scripts/remote-release.sh "$SSH_TARGET:$REMOTE_DIR/"
      ssh "$SSH_TARGET" "bash '$REMOTE_DIR/remote-release.sh' '$REMOTE_DIR' '$BLOG_IMAGE' '$BLOG_PORT'"
    else
      ssh "$SSH_TARGET" "bash '$REMOTE_DIR/remote-release.sh' '$REMOTE_DIR' rollback '$BLOG_PORT'"
    fi
    ;;
  *) echo 'Usage: scripts/deploy.sh build [version] | local | stop | publish | rollback' ;;
esac
