#!/usr/bin/env bash
# Скачивает vpn_logo.png из upstream (файл в .gitignore из‑за размера).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL="https://raw.githubusercontent.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/main/vpn_logo.png"
curl -fsSL -o "${ROOT}/vpn_logo.png" "$URL"
echo "OK ${ROOT}/vpn_logo.png"
