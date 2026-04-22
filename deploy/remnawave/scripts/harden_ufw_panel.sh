#!/usr/bin/env bash
# Host firewall (Wirefall) for Remnawave Panel server:
# default deny incoming, allow SSH + HTTP/HTTPS for Caddy.
#
# Usage (from repo clone on server):
#   sudo CONFIRM=1 bash deploy/remnawave/scripts/harden_ufw_panel.sh
# Restrict SSH to your IP only (strongly recommended):
#   sudo CONFIRM=1 ADMIN_SSH_CIDR=203.0.113.10/32 bash deploy/remnawave/scripts/harden_ufw_panel.sh
#
# Cloudflare origin lockdown (80/443 only from CF) is separate:
#   deploy/remnawave/scripts/lockdown_cloudflare_origin.sh

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

if [[ "${CONFIRM:-}" != "1" ]]; then
  echo "Refusing: set CONFIRM=1 after reading deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md" >&2
  exit 1
fi

if ! command -v ufw >/dev/null 2>&1; then
  echo "ufw not installed. Example: apt-get update && apt-get install -y ufw" >&2
  exit 1
fi

readonly ADMIN_SSH_CIDR="${ADMIN_SSH_CIDR:-any}"
readonly SSH_PORT="${SSH_PORT:-22}"

echo "[1/4] ufw: default policies (deny incoming, allow outgoing)"
ufw default deny incoming
ufw default allow outgoing

echo "[2/4] ufw: reset rules (idempotent re-run clears numbered rules)"
ufw --force reset

if [[ "${ADMIN_SSH_CIDR}" == "any" ]]; then
  echo "[3/4] ufw: allow SSH on ${SSH_PORT}/tcp from ANYWHERE (set ADMIN_SSH_CIDR to tighten)"
  ufw allow "${SSH_PORT}/tcp" comment 'ssh'
else
  echo "[3/4] ufw: allow SSH on ${SSH_PORT}/tcp only from ${ADMIN_SSH_CIDR}"
  ufw allow from "${ADMIN_SSH_CIDR}" to any port "${SSH_PORT}" proto tcp comment 'ssh-admin'
fi

echo "[3/4] ufw: allow HTTP/HTTPS for Caddy (Cloudflare still filters at application layer)"
ufw allow 80/tcp comment 'http-caddy'
ufw allow 443/tcp comment 'https-caddy'

echo "[4/4] ufw: enable"
ufw --force enable

ufw status verbose

echo
echo "Done. Next: enable Cloudflare origin lockdown if not yet:"
echo "  sudo systemctl enable --now remnawave-cloudflare-origin.service remnawave-cloudflare-origin.timer"
echo "See: deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md"
