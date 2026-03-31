#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_DIR="${XRAY_LOCATION_ASSET:-${ROOT_DIR}/var/vpn-product-predeploy3/assets}"
RESOURCES_DIR="${ROOT_DIR}/resources"
GEOIP_URL="${XRAY_TEST_GEOIP_URL:-https://github.com/v2fly/geoip/releases/latest/download/geoip.dat}"
GEOSITE_URL="${XRAY_TEST_GEOSITE_URL:-https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat}"

mkdir -p "${RESOURCES_DIR}"

for file in geoip.dat geosite.dat; do
  if [[ -f "${RESOURCES_DIR}/${file}" ]]; then
    continue
  fi
  if [[ ! -f "${ASSET_DIR}/${file}" ]]; then
    url="${GEOIP_URL}"
    if [[ "${file}" == "geosite.dat" ]]; then
      url="${GEOSITE_URL}"
    fi
    echo "missing local asset ${ASSET_DIR}/${file}; downloading from ${url}"
    curl -fsSL "${url}" -o "${RESOURCES_DIR}/${file}"
    continue
  fi
  cp "${ASSET_DIR}/${file}" "${RESOURCES_DIR}/${file}"
done

echo "prepared test assets in ${RESOURCES_DIR}"
