## Миграция на Remnawave

Мы переходим с текущей архитектуры на базе **`vpn-productd` + 3x-ui** к **Remnawave Panel + Remnawave Node**.

### Почему

- Remnawave разделяет управление (Panel) и трафик (Node), и поддерживает актуальный workflow управления нодами/подписками.
- `vpn-productd` и связанная доменная логика продукта выводятся из эксплуатации.

### Текущий статус

**Этап 1 из N (подготовка репозитория к деплою Remnawave):**

- добавлены docker-compose/env/скрипты для Remnawave Panel + Postgres + subscription-page
- добавлены docker-compose/env/скрипты для Remnawave Node (отдельный сервер)
- добавлен systemd backup timer для бэкапов Postgres базы Remnawave (retention 14 дней)
- старый код не удаляется, но помечается к удалению на следующем этапе

### Чего ещё нет (будет в следующих этапах)

- Оплата/платёжная интеграция (привязка к биллингу Remnawave)
- Миграция старых пользователей/данных из vpn-productd

### Telegram-бот и Remnawave

В **`apps/vpn-telegram-bot/`** включён режим **`VPN_BACKEND=remnawave`**: бот ходит в Panel REST API (`/api/users`, `/api/system/health`, …) по [community Python SDK](https://github.com/remnawave/python-sdk) / официальным путям.

Переменные: см. `apps/vpn-telegram-bot/.env.example` (`REMNAWAVE_PANEL_URL`, `REMNAWAVE_API_TOKEN`, `REMNAWAVE_INTERNAL_SQUAD_UUIDS`, опционально `REMNAWAVE_CADDY_TOKEN`).

Режим по умолчанию **`VPN_BACKEND=productd`** — прежнее поведение с `VPN_API_URL` / `VPN_API_TOKEN`.

### Где смотреть инструкции деплоя

- `deploy/remnawave/README.md`

