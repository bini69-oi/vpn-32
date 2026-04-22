#!/usr/bin/env bash
# Выгрузка «понятных» логов в CSV + срез stdout контейнера бота в .log
# Требуется: docker compose up -d (контейнер db должен быть запущен).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p logs

TS="$(date -u +"%Y%m%d-%H%M%SZ")"

if ! docker compose ps -q db 2>/dev/null | grep -q .; then
  echo "Контейнер Postgres (db) не запущен. Выполни из этой папки: docker compose up -d" >&2
  exit 1
fi

run_sql_csv() {
  local sql_basename="$1"
  local out_stamped="logs/${sql_basename}_${TS}.csv"
  local out_latest="logs/latest_${sql_basename}.csv"
  docker compose exec -T db sh -c 'exec psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}" -f -' \
    <"${ROOT}/scripts/sql/${sql_basename}.sql" >"${ROOT}/${out_stamped}"
  cp -f "${ROOT}/${out_stamped}" "${ROOT}/${out_latest}"
  echo "OK  ${out_latest}"
}

run_sql_csv export_purchases
run_sql_csv export_referrals
run_sql_csv export_timeline

# Сырой лог процесса бота (то, что в docker compose logs)
if docker compose ps -q bot 2>/dev/null | grep -q .; then
  docker compose logs --no-color --tail=5000 bot >"${ROOT}/logs/docker_bot_${TS}.log" 2>&1 || true
  cp -f "${ROOT}/logs/docker_bot_${TS}.log" "${ROOT}/logs/latest_docker_bot.log"
  echo "OK  logs/latest_docker_bot.log"
else
  echo "(skip) контейнер bot не запущен — docker-лог не выгружен" >&2
fi

echo
echo "Открой в Excel / Numbers / LibreOffice:"
echo "  ${ROOT}/logs/latest_export_purchases.csv   — все заявки на оплату"
echo "  ${ROOT}/logs/latest_export_referrals.csv  — рефералы и оплаты приглашённых"
echo "  ${ROOT}/logs/latest_export_timeline.csv  — лента событий"
echo "  ${ROOT}/logs/latest_docker_bot.log        — последние строки лога контейнера"
