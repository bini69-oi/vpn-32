#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash deploy/remnawave/scripts/install_node.sh"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

maybe_docker_hub_login() {
  if [[ -z "${DOCKERHUB_USER:-}" ]]; then
    return 0
  fi
  local pw="${DOCKERHUB_TOKEN:-${DOCKERHUB_PASSWORD:-}}"
  if [[ -z "${pw}" ]]; then
    echo "WARNING: DOCKERHUB_USER is set but DOCKERHUB_TOKEN (or DOCKERHUB_PASSWORD) is empty; skipping docker login."
    return 0
  fi
  echo "Logging in to Docker Hub as ${DOCKERHUB_USER}..."
  printf '%s\n' "${pw}" | docker login -u "${DOCKERHUB_USER}" --password-stdin
}

echo "[1/4] Docker."
if docker version >/dev/null 2>&1; then
  echo "Docker already present; skipping get.docker.com."
else
  curl -fsSL https://get.docker.com | sh
fi

echo "[2/4] Creating RemnaNode directory."
mkdir -p /opt/remnanode

echo "[3/4] Installing node compose and env example."
install -m 0644 "${PROJECT_DIR}/deploy/remnawave/node/docker-compose.yml" /opt/remnanode/docker-compose.yml
if [[ ! -f /opt/remnanode/.env ]]; then
  install -m 0644 "${PROJECT_DIR}/deploy/remnawave/node/.env.example" /opt/remnanode/.env
else
  echo "Keeping existing /opt/remnanode/.env."
fi

echo "IMPORTANT: edit /opt/remnanode/.env (SECRET_KEY, NODE_PORT) before starting."
echo "Docs: https://docs.rw/docs/install/remnawave-node/"

echo "[4/4] Starting Remnawave Node container."
maybe_docker_hub_login
cd /opt/remnanode
if ! docker compose up -d; then
  echo "Docker Hub rate limit? Run: docker login"
  echo "or export DOCKERHUB_USER + DOCKERHUB_TOKEN, then: cd /opt/remnanode && docker compose up -d"
  exit 1
fi

echo "Node logs:"
echo "  docker compose -f /opt/remnanode/docker-compose.yml logs -f -t"
