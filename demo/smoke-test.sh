#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
export DEMO_HTTP_PORT="$((20000 + RANDOM % 20000))"
project="zero-trust-demo-${RANDOM}-$$"
compose=(docker compose --project-name "$project" --file demo/compose.yaml)
cleanup() {
  local status=$?
  local cleanup_failed=false
  local remaining
  trap - EXIT
  set +e
  if ! "${compose[@]}" down --remove-orphans >/dev/null 2>&1; then
    echo 'Could not clean up the temporary network demo.' >&2
    cleanup_failed=true
  fi
  if ! docker info >/dev/null 2>&1; then
    echo 'Docker is unavailable; temporary network-demo resources could not be verified.' >&2
    cleanup_failed=true
  else
    for resource in containers networks; do
      case "$resource" in
        containers) if ! remaining="$(docker ps --all --quiet --filter "label=com.docker.compose.project=$project" 2>/dev/null)"; then echo 'Could not verify temporary network-demo containers.' >&2; cleanup_failed=true; continue; fi ;;
        networks) if ! remaining="$(docker network ls --quiet --filter "label=com.docker.compose.project=$project" 2>/dev/null)"; then echo 'Could not verify temporary network-demo networks.' >&2; cleanup_failed=true; continue; fi ;;
      esac
      if [[ -n "$remaining" ]]; then
        echo "Temporary network-demo $resource remain after cleanup: $remaining" >&2
        cleanup_failed=true
      fi
    done
  fi
  if [[ "$status" -eq 0 && "$cleanup_failed" == true ]]; then status=1; fi
  exit "$status"
}
trap cleanup EXIT

"${compose[@]}" up --detach
base_url="http://127.0.0.1:${DEMO_HTTP_PORT}/"
public_status=''
for _ in {1..30}; do
  public_status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
    -H 'Host: public.localhost' "$base_url" || true)"
  [[ "$public_status" == 200 ]] && break
  sleep 1
done
[[ "$public_status" == 200 ]] || { echo "Public route returned $public_status, expected 200." >&2; exit 1; }

admin_status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
  -H 'Host: admin.localhost' "$base_url")"
[[ "$admin_status" == 403 ]] || { echo "Host admin route returned $admin_status, expected 403." >&2; exit 1; }
"${compose[@]}" --profile test run --rm private-client >/dev/null
echo 'PASS: public route is reachable, host admin route is denied, private client is allowed.'
