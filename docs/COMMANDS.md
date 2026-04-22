# Commands cheat-sheet

Все рабочие команды для Remnawave-стека.

## Telegram-бот Bedolaga (`apps/bedolaga-bot`)

Из корня репозитория:

```bash
make bot-up       # docker compose up -d (+ fetch vpn_logo.png при необходимости)
make bot-logs     # tail -f логов
make bot-pull     # docker compose pull && up -d  (обновление)
make bot-restart  # рестарт без обновления
make bot-down     # stop + remove
make bot-ps       # docker compose ps
make bot-assets   # только скачать vpn_logo.png
```

Напрямую:

```bash
cd apps/bedolaga-bot
curl -fsSL -o .env https://raw.githubusercontent.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/main/.env.example
# отредактируй .env (POSTGRES_PASSWORD, BOT_TOKEN, ADMIN_IDS, REMNAWAVE_API_*, платёжки)
bash scripts/fetch_assets.sh
docker compose pull
docker compose up -d
docker compose logs -f bot
```

Файловые логи приложения на хосте: `apps/bedolaga-bot/logs/` (volume `./logs` → `/app/logs`).

Документация по командам админа в Telegram — [docs.bedolagam.ru](https://docs.bedolagam.ru).

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
make verify        # secret-scan + docker compose config (bedolaga-bot)
```

## Архив

- Jolymmiels `remnawave-telegram-shop`: [`archive/telegram-shop-jolymmiels/`](../archive/telegram-shop-jolymmiels/)
- Команды для `vpn-productd` / 3x-ui: [`archive/vpn-productd/docs/`](../archive/vpn-productd/docs/)
