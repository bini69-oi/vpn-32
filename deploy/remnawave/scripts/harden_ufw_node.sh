#!/usr/bin/env bash
# Host firewall (Wirefall) for Remnawave Node server:
# default deny incoming; SSH; NODE_PORT for VPN clients (see NODE_INBOUND).
#
# Usage (typical Remnawave — users connect to NODE_PORT from the Internet):
#   sudo CONFIRM=1 NODE_PORT=2222 bash deploy/remnawave/scripts/harden_ufw_node.sh
#
# Optional: restrict SSH to your admin IP
#   sudo CONFIRM=1 NODE_PORT=2222 ADMIN_SSH_CIDR=203.0.113.10/32 bash ...
#
# Rare: NODE_INBOUND=panel-only PANEL_IP=1.2.3.4 — only if your setup does not expose VPN on this port
#   (breaks normal client VPN if the same port serves users).
#
# Remnawave Node uses network_mode: host — inbound hits host INPUT / ufw.

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

if [[ "${CONFIRM:-}" != "1" ]]; then
  echo "Refusing: set CONFIRM=1 after reading deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md" >&2
  exit 1
fi

if [[ -z "${NODE_PORT:-}" ]]; then
  echo "Set NODE_PORT (same as in Remnawave UI → Nodes)." >&2
  exit 1
fi

readonly NODE_INBOUND="${NODE_INBOUND:-clients}"
if [[ "${NODE_INBOUND}" == "panel-only" ]]; then
  if [[ -z "${PANEL_IP:-}" ]]; then
    echo "NODE_INBOUND=panel-only requires PANEL_IP." >&2
    exit 1
  fi
fi

if ! command -v ufw >/dev/null 2>&1; then
  echo "ufw not installed. Example: apt-get update && apt-get install -y ufw" >&2
  exit 1
fi

readonly ADMIN_SSH_CIDR="${ADMIN_SSH_CIDR:-any}"
readonly SSH_PORT="${SSH_PORT:-22}"

echo "[1/4] ufw: default policies"
ufw default deny incoming
ufw default allow outgoing

echo "[2/4] ufw: reset"
ufw --force reset

if [[ "${ADMIN_SSH_CIDR}" == "any" ]]; then
  echo "[3/4] ufw: SSH ${SSH_PORT}/tcp from anywhere (set ADMIN_SSH_CIDR to tighten)"
  ufw allow "${SSH_PORT}/tcp" comment 'ssh'
else
  echo "[3/4] ufw: SSH ${SSH_PORT}/tcp only from ${ADMIN_SSH_CIDR}"
  ufw allow from "${ADMIN_SSH_CIDR}" to any port "${SSH_PORT}" proto tcp comment 'ssh-admin'
fi

if [[ "${NODE_INBOUND}" == "panel-only" ]]; then
  echo "[3/4] ufw: NODE_PORT ${NODE_PORT}/tcp only from panel ${PANEL_IP}"
  ufw allow from "${PANEL_IP}" to any port "${NODE_PORT}" proto tcp comment 'remnawave-node-from-panel-only'
else
  echo "[3/4] ufw: NODE_PORT ${NODE_PORT}/tcp from anywhere (VPN clients; set NODE_INBOUND=panel-only if you know you need it)"
  ufw allow "${NODE_PORT}/tcp" comment 'remnawave-vpn-node'
fi

echo "[4/4] ufw: enable"
ufw --force enable

ufw status verbose

echo
echo "Done. NODE_INBOUND=${NODE_INBOUND}. See deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md"
