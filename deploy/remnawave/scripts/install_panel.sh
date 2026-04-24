#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash deploy/remnawave/scripts/install_panel.sh"
  exit 1
fi

usage() {
  cat <<'EOF'
Usage:
  install_panel.sh                          # install files; start compose only if already configured
  install_panel.sh PANEL_FQDN SUB_FQDN      # set domains, JWT secrets, Caddyfile, then docker compose up -d

Example:
  install_panel.sh panel.example.com sub.example.com

DNS: A/AAAA for both names must point to this server before HTTPS (Let's Encrypt) works.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 0 && "$#" -ne 2 ]]; then
  usage
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENVF="/opt/remnawave/.env"
CADDYF="/opt/remnawave/caddy/Caddyfile"

panel_env_complete() {
  [[ -f "${ENVF}" ]] || return 1
  [[ -f "${CADDYF}" ]] || return 1
  grep -qE '^JWT_AUTH_SECRET=""' "${ENVF}" && return 1
  grep -qE '^JWT_API_TOKENS_SECRET=""' "${ENVF}" && return 1
  grep -qE '^SUB_PUBLIC_DOMAIN=TODO' "${ENVF}" && return 1
  grep -qE '^PANEL_DOMAIN=TODO' "${ENVF}" && return 1
  grep -qE '^FRONT_END_DOMAIN=TODO' "${ENVF}" && return 1
  grep -q 'https://PANEL_DOMAIN' "${CADDYF}" 2>/dev/null && return 1
  grep -q 'https://SUB_DOMAIN' "${CADDYF}" 2>/dev/null && return 1
  return 0
}

apply_domains_and_secrets() {
  local panel="$1"
  local sub="$2"
  local jwt1 jwt2 api_tok

  jwt1="$(openssl rand -hex 32)"
  jwt2="$(openssl rand -hex 32)"
  api_tok="$(openssl rand -hex 24)"

  sed -i \
    -e "s|^JWT_AUTH_SECRET=.*|JWT_AUTH_SECRET=\"${jwt1}\"|" \
    -e "s|^JWT_API_TOKENS_SECRET=.*|JWT_API_TOKENS_SECRET=\"${jwt2}\"|" \
    -e "s|^PANEL_DOMAIN=.*|PANEL_DOMAIN=${panel}|" \
    -e "s|^FRONT_END_DOMAIN=.*|FRONT_END_DOMAIN=https://${panel}|" \
    -e "s|^SUB_PUBLIC_DOMAIN=.*|SUB_PUBLIC_DOMAIN=${sub}|" \
    -e "s|^REMNAWAVE_API_TOKEN=.*|REMNAWAVE_API_TOKEN=${api_tok}|" \
    "${ENVF}"

  sed -i \
    -e "s|https://PANEL_DOMAIN|https://${panel}|g" \
    -e "s|https://SUB_DOMAIN|https://${sub}|g" \
    "${CADDYF}"

  echo "Generated JWT secrets and placeholder REMNAWAVE_API_TOKEN."
  echo "Replace REMNAWAVE_API_TOKEN in ${ENVF} after creating a token in the panel UI (Settings -> API Tokens), then: docker compose -f /opt/remnawave/docker-compose.yml up -d"
}

echo "[1/6] Docker."
if docker version >/dev/null 2>&1; then
  echo "Docker already present; skipping get.docker.com."
else
  curl -fsSL https://get.docker.com | sh
fi

echo "[2/6] Creating Remnawave directories."
mkdir -p /opt/remnawave
mkdir -p /opt/remnawave/caddy

echo "[3/6] Installing panel compose and supporting files."
install -m 0644 "${PROJECT_DIR}/deploy/remnawave/panel/docker-compose.yml" /opt/remnawave/docker-compose.yml
if [[ ! -f "${ENVF}" ]]; then
  install -m 0644 "${PROJECT_DIR}/deploy/remnawave/panel/.env.example" "${ENVF}"
else
  echo "Keeping existing ${ENVF}."
fi
if [[ ! -f "${CADDYF}" ]]; then
  install -m 0644 "${PROJECT_DIR}/deploy/remnawave/panel/caddy/Caddyfile" "${CADDYF}"
else
  echo "Keeping existing ${CADDYF} (remove it to reinstall the template from the repo)."
fi
install -m 0755 "${PROJECT_DIR}/deploy/remnawave/scripts/lockdown_cloudflare_origin.sh" /usr/local/bin/remnawave-cloudflare-origin.sh
install -m 0644 "${PROJECT_DIR}/deploy/remnawave/systemd/remnawave-cloudflare-origin.service" /etc/systemd/system/remnawave-cloudflare-origin.service
install -m 0644 "${PROJECT_DIR}/deploy/remnawave/systemd/remnawave-cloudflare-origin.timer" /etc/systemd/system/remnawave-cloudflare-origin.timer

if [[ "$#" -eq 2 ]]; then
  echo "[3b/6] Applying panel/sub domains and secrets."
  apply_domains_and_secrets "$1" "$2"
fi

echo "Docs: https://docs.rw/docs/install/remnawave-panel/"

START=0
if [[ "$#" -eq 2 ]]; then
  START=1
elif panel_env_complete; then
  START=1
fi

if [[ "${START}" -eq 1 ]]; then
  echo "[4/6] Starting Remnawave Panel containers."
  cd /opt/remnawave
  docker compose up -d
else
  echo "[4/6] Skipping docker compose (not configured yet)."
  echo "Run with two arguments (panel FQDN and subscription FQDN), for example:"
  echo "  bash ${PROJECT_DIR}/deploy/remnawave/scripts/install_panel.sh panel.example.com sub.example.com"
  echo "Or edit ${ENVF} and ${CADDYF}, then: cd /opt/remnawave && docker compose up -d"
fi

echo "[5/6] Installing backup script + systemd timer (daily 00:00 UTC)."
install -m 0755 "${PROJECT_DIR}/deploy/remnawave/scripts/backup_panel.sh" /usr/local/bin/remnawave-backup.sh
install -m 0644 "${PROJECT_DIR}/deploy/remnawave/systemd/vpn-backup.service" /etc/systemd/system/vpn-backup.service
install -m 0644 "${PROJECT_DIR}/deploy/remnawave/systemd/vpn-backup.timer" /etc/systemd/system/vpn-backup.timer
mkdir -p /var/backups/remnawave

systemctl daemon-reload
systemctl enable --now vpn-backup.timer
systemctl start vpn-backup.service || true

echo "[6/6] Done."
echo "Panel logs:"
echo "  docker compose -f /opt/remnawave/docker-compose.yml logs -f -t"
echo "Backup status:"
echo "  systemctl status vpn-backup.timer --no-pager"
echo "Cloudflare origin hardening (only after orange-cloud proxy is enabled for panel/sub domains):"
echo "  systemctl enable --now remnawave-cloudflare-origin.service"
echo "  systemctl enable --now remnawave-cloudflare-origin.timer"
