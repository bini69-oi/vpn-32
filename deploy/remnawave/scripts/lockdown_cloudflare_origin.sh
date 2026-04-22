#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo /usr/local/bin/remnawave-cloudflare-origin.sh"
  exit 1
fi

readonly CF_IPV4_URL="${CF_IPV4_URL:-https://www.cloudflare.com/ips-v4}"
readonly CF_IPV6_URL="${CF_IPV6_URL:-https://www.cloudflare.com/ips-v6}"
readonly TCP_PORTS="${TCP_PORTS:-80,443}"
readonly CHAIN_NAME="REMNAWAVE_CLOUDFLARE_ORIGIN"

need_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}" >&2
    exit 1
  fi
}

load_ranges() {
  local url="$1"
  curl --fail --silent --show-error --location \
    --connect-timeout 10 \
    --retry 3 \
    --retry-delay 2 \
    "${url}" | sed '/^[[:space:]]*$/d'
}

refresh_chain() {
  local bin="$1"
  local source_url="$2"
  local ranges
  local inserted=0

  if ! command -v "${bin}" >/dev/null 2>&1; then
    echo "Skipping ${bin}: command not found."
    return 0
  fi

  ranges="$(load_ranges "${source_url}")"

  "${bin}" -w -N "${CHAIN_NAME}" 2>/dev/null || true
  "${bin}" -w -F "${CHAIN_NAME}"

  while IFS= read -r cidr; do
    [[ -n "${cidr}" ]] || continue
    "${bin}" -w -A "${CHAIN_NAME}" -p tcp -m multiport --dports "${TCP_PORTS}" -s "${cidr}" -j RETURN
    inserted=1
  done <<< "${ranges}"

  if [[ "${inserted}" -eq 0 ]]; then
    echo "Refusing to install empty Cloudflare allowlist from ${source_url}" >&2
    exit 1
  fi

  "${bin}" -w -A "${CHAIN_NAME}" -p tcp -m multiport --dports "${TCP_PORTS}" -j DROP
  "${bin}" -w -C INPUT -p tcp -m multiport --dports "${TCP_PORTS}" -j "${CHAIN_NAME}" 2>/dev/null ||
    "${bin}" -w -I INPUT 1 -p tcp -m multiport --dports "${TCP_PORTS}" -j "${CHAIN_NAME}"
}

need_cmd curl
need_cmd sed
need_cmd iptables

echo "Refreshing Cloudflare origin allowlist for TCP ports ${TCP_PORTS}..."
refresh_chain iptables "${CF_IPV4_URL}"
refresh_chain ip6tables "${CF_IPV6_URL}"

echo
echo "Cloudflare origin allowlist updated."
echo "Check rules with:"
echo "  iptables -S ${CHAIN_NAME}"
echo "  ip6tables -S ${CHAIN_NAME}"
