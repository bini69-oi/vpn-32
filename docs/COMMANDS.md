# Commands cheat-sheet

Все рабочие команды для Remnawave-стека.

## Telegram-бот (`apps/telegram-shop`)

Из корня репозитория:

```bash
make bot-up       # docker compose up -d
make bot-logs     # tail -f логов
make bot-pull     # docker compose pull && up -d  (обновление)
make bot-restart  # рестарт без обновления
make bot-down     # stop + remove
make bot-ps       # docker compose ps
```

Напрямую через docker compose:

```bash
cd apps/telegram-shop
cp .env.sample .env         # заполни значения
docker compose pull
docker compose up -d
docker compose logs -f bot
```

Обновление образа:

```bash
cd apps/telegram-shop
docker compose pull
docker compose down && docker compose up -d
```

Админские команды бота (в Telegram, от имени `ADMIN_TELEGRAM_ID`):

- `/sync` — синхронизировать пользователей с Remnawave Panel (удалит из БД бота тех, кого нет в панели).

## Remnawave Panel + Node (production)

Полный гайд: [`deploy/remnawave/README.md`](../deploy/remnawave/README.md).

Сервер панели:

```bash
sudo bash deploy/remnawave/scripts/install_panel.sh
sudoedit /opt/remnawave/.env   # PANEL_DOMAIN, JWT_*, SUB_PUBLIC_DOMAIN, POSTGRES_PASSWORD
cd /opt/remnawave && docker compose pull && docker compose up -d
```

Сервер ноды:

```bash
sudo bash deploy/remnawave/scripts/install_node.sh
sudoedit /opt/remnanode/.env   # NODE_PORT, SECRET_KEY (взять в UI панели → Add Node)
cd /opt/remnanode && docker compose pull && docker compose up -d
```

Бэкап Postgres панели:

```bash
sudo bash deploy/remnawave/scripts/backup_panel.sh   # см. README про cron/timer
```

## Полезные API-вызовы Remnawave

```bash
PANEL=https://panel.example.com
TOKEN=<bearer из Settings → API tokens>

curl -sS -H "Authorization: Bearer $TOKEN" "$PANEL/api/system/health" | jq
curl -sS -H "Authorization: Bearer $TOKEN" "$PANEL/api/users/by-telegram-id/123456789" | jq
```

## Качество / CI локально

```bash
make secret-scan   # поиск утечек
make verify        # secret-scan + docker compose config
```

## Архив

- Собственный Python-бот со всеми тестами: [`archive/vpn-telegram-bot-custom/`](../archive/vpn-telegram-bot-custom/).
- Команды для `vpn-productd` / 3x-ui: [`archive/vpn-productd/docs/`](../archive/vpn-productd/docs/).
