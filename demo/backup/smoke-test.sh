#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
export MSYS_NO_PATHCONV=1

export RESTIC_DEMO_PROJECT="homelab-backup-smoke-${RANDOM}-$$"
secret_file="demo/backup/secrets/restic_password.txt"
created_secret=false
created_secret_dir=false

compose=(docker compose --project-name "$RESTIC_DEMO_PROJECT" --file demo/backup/compose.yaml)
cleanup() {
  local status=$?
  local cleanup_failed=false
  local remaining
  trap - EXIT
  set +e
  if ! "${compose[@]}" down --volumes --remove-orphans >/dev/null 2>&1; then
    echo 'Could not clean up the temporary backup demo.' >&2
    cleanup_failed=true
  fi
  if ! docker info >/dev/null 2>&1; then
    echo 'Docker is unavailable; temporary backup-demo resources could not be verified.' >&2
    cleanup_failed=true
  else
    for resource in containers volumes; do
      case "$resource" in
        containers) if ! remaining="$(docker ps --all --quiet --filter "label=com.docker.compose.project=$RESTIC_DEMO_PROJECT" 2>/dev/null)"; then echo 'Could not verify temporary backup-demo containers.' >&2; cleanup_failed=true; continue; fi ;;
        volumes) if ! remaining="$(docker volume ls --quiet --filter "label=com.docker.compose.project=$RESTIC_DEMO_PROJECT" 2>/dev/null)"; then echo 'Could not verify temporary backup-demo volumes.' >&2; cleanup_failed=true; continue; fi ;;
      esac
      if [[ -n "$remaining" ]]; then
        echo "Temporary backup-demo $resource remain after cleanup: $remaining" >&2
        cleanup_failed=true
      fi
    done
  fi
  if [[ "$created_secret" == true ]]; then
    if ! rm -f -- "$secret_file"; then
      echo "Could not remove the temporary Restic password file: $secret_file" >&2
      cleanup_failed=true
    fi
  fi
  if [[ "$created_secret_dir" == true ]]; then rmdir demo/backup/secrets 2>/dev/null || true; fi
  if [[ "$status" -eq 0 && "$cleanup_failed" == true ]]; then status=1; fi
  exit "$status"
}
trap cleanup EXIT

if [[ ! -d demo/backup/secrets ]]; then
  created_secret_dir=true
  mkdir -p demo/backup/secrets
fi
if [[ ! -f "$secret_file" ]]; then
  created_secret=true
  openssl rand -hex 32 > "$secret_file"
fi

"${compose[@]}" run --rm restic init
"${compose[@]}" run --rm restic backup /source
"${compose[@]}" run --rm restic check
"${compose[@]}" run --rm restic restore latest --target /restore
"${compose[@]}" run --rm backup-checker

echo 'PASS: encrypted Restic repository initialized, checked, restored, and compared with the synthetic fixture.'
