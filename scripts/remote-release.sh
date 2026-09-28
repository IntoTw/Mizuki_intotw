#!/usr/bin/env bash
set -euo pipefail
cd "$1"
exec 9>.release.lock
flock -n 9 || { echo 'Another release is running'; exit 1; }
IMAGE=$2
PORT=$3
OLD=$(cat current 2>/dev/null || true)
if [[ "$IMAGE" == rollback ]]; then IMAGE=$(cat previous); fi
[[ "$IMAGE" =~ ^intotw-blog:[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || exit 1
[[ "$PORT" =~ ^[0-9]+$ ]] || exit 1
[[ $(docker image inspect --format '{{.Architecture}}' "$IMAGE") == amd64 ]] || exit 1
start() {
  BLOG_IMAGE="$1" BLOG_PORT="$PORT" docker compose -p mizuki-blog -f compose.yml up -d --wait --wait-timeout 90
}
if ! start "$IMAGE" || ! curl --noproxy '*' --max-time 15 --fail --silent "http://127.0.0.1:$PORT/" >/dev/null; then
  echo 'Release failed; restoring previous container'
  if [[ -n "$OLD" ]]; then start "$OLD"; else
    BLOG_IMAGE="$IMAGE" BLOG_PORT="$PORT" docker compose -p mizuki-blog -f compose.yml down
  fi
  exit 1
fi
if [[ -n "$OLD" && "$OLD" != "$IMAGE" ]]; then printf '%s\n' "$OLD" > previous; fi
printf '%s\n' "$IMAGE" > current.tmp
mv current.tmp current
echo "Healthy: $IMAGE on 127.0.0.1:$PORT. Host Nginx unchanged."
