<div align="center">

# VPN Product — Remnawave + готовый Telegram-бот

**Коммерческий VPN-сервис:** Remnawave Panel + Remnawave Node + готовый Telegram-shop бот [Jolymmiels/remnawave-telegram-shop](https://github.com/Jolymmiels/remnawave-telegram-shop). Всё ставится в 3 команды на 2–3 серверах.

[![CI](https://img.shields.io/github/actions/workflow/status/bini69-oi/vpn-work-xray/ci.yml?style=flat-square&label=CI)](https://github.com/bini69-oi/vpn-work-xray/actions)
[![Remnawave](https://img.shields.io/badge/Remnawave-Panel%20%2B%20Node-blue?style=flat-square)](https://docs.rw)
[![Bot](https://img.shields.io/badge/Bot-remnawave--telegram--shop-26A5E4?style=flat-square&logo=telegram&logoColor=white)](https://github.com/Jolymmiels/remnawave-telegram-shop)
[![License](https://img.shields.io/badge/License-MPL--2.0-green?style=flat-square)](LICENSE)

</div>

---

## Что это

- [**Remnawave Panel + Node**](deploy/remnawave/README.md) — официальный Docker-стек Remnawave ([docs.rw](https://docs.rw/)). Панель управляет пользователями и подписками, нода шифрует трафик (VLESS / REALITY через встроенный Xray-core).
- [**Telegram-бот**](apps/telegram-shop/README.md) — готовое opensource-решение `remnawave-telegram-shop`: покупка подписок (1/3/6/12 мес.), YooKassa, CryptoPay, Telegram Stars, Tribute, триал, реф-программа, `/sync` с панелью, уведомления за 3 дня до окончания. Ставится одним `docker compose up -d`.
- **2–3 сервера** без лишней обвязки: Panel, Node, бот (бот можно поставить рядом с Panel).

> **История.** Раньше здесь жил Go-сервис `vpn-productd` + форк Xray-core + Mini App + собственный Python-бот. Всё снято с эксплуатации и вынесено в [`archive/`](archive/README.md). Теперь ядро — официальный Remnawave, а продаёт подписки готовый, давно вылизанный бот.

---

## Архитектура

```
 ┌─────────────────────────────┐        ┌──────────────────────────────┐
 │  Сервер 1 — Remnawave Panel │        │  Сервер 3 (или рядом с 1)    │
 │  ┌───────────────────────┐  │◀──────▶│  Telegram-shop bot + PG      │
 │  │ remnawave (REST API)  │  │ HTTPS  │  docker compose up -d        │
 │  │ Postgres  Redis       │  │        │  apps/telegram-shop/         │
 │  │ subscription-page     │  │        └──────────────┬───────────────┘
 │  │ Caddy (HTTPS)         │  │                       │
 │  └───────────────────────┘  │                       ▼
 └─────────────┬───────────────┘                ┌─────────────┐
               │ NODE_PORT только для IP панели │ Telegram    │
               │                                │  Bot API    │
 ┌─────────────┴───────────────┐                └─────────────┘
 │  Сервер 2 — Remnawave Node  │                       ▲
 │  ┌───────────────────────┐  │                       │
 │  │ remnawave-node        │  │                       │
 │  │ xray-core (VLESS/RTY) │  │◀── VPN-трафик ────────┘  Пользователь
 │  └───────────────────────┘  │                          (Happ / VLESS-клиент)
 └─────────────────────────────┘
```

Шифрование трафика выполняет **Remnawave Node** (встроенный Xray-core, VLESS + REALITY). Нам свой VPN-ядро писать не нужно — нода уже всё делает.

---

## Быстрый старт (2–3 сервера)

### 1. Сервер 1 — Remnawave Panel

```bash
git clone https://github.com/bini69-oi/vpn-work-xray.git
cd vpn-work-xray

sudo bash deploy/remnawave/scripts/install_panel.sh
sudoedit /opt/remnawave/.env     # PANEL_DOMAIN, SUB_PUBLIC_DOMAIN, JWT_AUTH_SECRET, JWT_API_TOKENS_SECRET
cd /opt/remnawave && docker compose up -d
# после включения orange-cloud proxy в Cloudflare:
sudo systemctl enable --now remnawave-cloudflare-origin.service
sudo systemctl enable --now remnawave-cloudflare-origin.timer
```

DNS: `PANEL_DOMAIN` и `SUB_DOMAIN` резолвятся на IP панели, Caddy сам выпустит SSL.
Первый зарегистрированный в UI пользователь — **super-admin** (подробности — [`deploy/remnawave/README.md`](deploy/remnawave/README.md)).

### 2. Сервер 2 — Remnawave Node

В UI Panel: `Management → Nodes → +` — получите `SECRET_KEY` и выберите `NODE_PORT`.

```bash
git clone https://github.com/bini69-oi/vpn-work-xray.git
cd vpn-work-xray
sudo bash deploy/remnawave/scripts/install_node.sh
sudoedit /opt/remnanode/.env     # NODE_PORT + SECRET_KEY из UI
cd /opt/remnanode && docker compose up -d
```

Фаервол: `NODE_PORT` открыт **только** для IP панели.

### 3. Telegram-бот (рядом с Panel или отдельный сервер)

```bash
cd apps/telegram-shop
cp .env.sample .env
# минимум:
#   TELEGRAM_TOKEN, ADMIN_TELEGRAM_ID,
#   REMNAWAVE_URL=https://panel.example.com,
#   REMNAWAVE_TOKEN=<bearer из UI панели: Settings → API tokens>,
#   PRICE_1/3/6/12, STARS_PRICE_1/3/6/12,
#   (опционально) SQUAD_UUIDS — UUID внутренних сквадов

docker compose pull
docker compose up -d
docker compose logs -f bot
```

Или из корня репозитория:

```bash
make bot-up       # up -d
make bot-logs     # tail логов
make bot-pull     # обновление образа
make bot-down     # stop + rm
```

---

## Что настраивается в `.env` бота

Все переменные — в [`apps/telegram-shop/.env.sample`](apps/telegram-shop/.env.sample). Ключевые:

| Переменная | Что это |
|---|---|
| `TELEGRAM_TOKEN` | Токен из @BotFather |
| `ADMIN_TELEGRAM_ID` | Твой Telegram ID (узнать у [@userinfobot](https://t.me/userinfobot)) |
| `REMNAWAVE_URL` | `https://panel.example.com` |
| `REMNAWAVE_TOKEN` | Bearer-токен из Panel → Settings → API tokens |
| `SQUAD_UUIDS` | UUID внутренних сквадов (если пусто — назначаются все) |
| `PRICE_1/3/6/12` | Цена в ₽ за 1/3/6/12 месяцев |
| `STARS_PRICE_1/3/6/12` | Цена в Telegram Stars |
| `TRIAL_DAYS`, `TRIAL_TRAFFIC_LIMIT` | Бесплатный триал |
| `REFERRAL_DAYS` | Бонус за реферала в днях |
| `YOOKASA_*`, `CRYPTO_PAY_*`, `TRIBUTE_*` | Платёжки (включаются только если заполнены) |
| `SUPPORT_URL`, `CHANNEL_URL`, … | Доп. кнопки в меню (пусто = скрыты) |

Полный список с описаниями: [upstream README](https://github.com/Jolymmiels/remnawave-telegram-shop#environment-variables).

---

## Команды

| Цель | Команда |
|------|---------|
| Поднять бота | `make bot-up` |
| Логи бота | `make bot-logs` |
| Обновить образ | `make bot-pull` |
| Перезапуск | `make bot-restart` |
| Остановить | `make bot-down` |
| Статус контейнеров | `make bot-ps` |
| Secret-scan | `make secret-scan` |
| Локальный прогон CI (secret-scan + `docker compose config`) | `make verify` |
| Установить git-хуки | `bash scripts/install_git_hooks.sh` |

Подробный справочник по установке Panel/Node, бэкапам и отладке — [`docs/COMMANDS.md`](docs/COMMANDS.md).

---

## Структура репозитория

| Путь | Назначение |
|------|------------|
| [`apps/telegram-shop/`](apps/telegram-shop/README.md) | Готовый Telegram-бот (`docker-compose.yaml` + `.env.sample`) |
| [`deploy/remnawave/`](deploy/remnawave/README.md) | Docker Compose + `install_*.sh` для Panel / Node + Caddy + systemd-бэкап |
| [`deploy/backups/`](deploy/backups/) | Скрипты бэкапа Postgres Remnawave |
| [`docs/`](docs/) | [COMMANDS.md](docs/COMMANDS.md), [CONTRIBUTING.md](docs/CONTRIBUTING.md) |
| [`scripts/`](scripts/) | `secret_scan.py`, git-хуки (`pre-commit`/`pre-push`) |
| [`archive/`](archive/README.md) | `vpn-productd/`, `vpn-telegram-bot-custom/`, `telegram-bot-legacy/`, `telegram-miniapp/` |

---

## CI / качество

GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)):

1. **`secret-scan`** — `scripts/secret_scan.py` ищет утечки токенов/ключей.
2. **`compose-lint`** — `docker compose config` валидирует [`apps/telegram-shop/docker-compose.yaml`](apps/telegram-shop/docker-compose.yaml) с примерами из `.env.sample`.

Собственный Python-бот со всеми 205 тестами (ruff + mypy + pytest --cov ≥ 80 %) лежит в [`archive/vpn-telegram-bot-custom/`](archive/vpn-telegram-bot-custom/). Если захочешь вернуться к своему боту — перенеси обратно в `apps/` и восстанови `bot-quality` job из истории `.github/workflows/ci.yml`.

---

## Git hooks

```bash
bash scripts/install_git_hooks.sh
```

- `pre-commit`: `make secret-scan`.
- `pre-push`: `make verify` (secret-scan + compose config).

---

## Документация

| Документ | Что внутри |
|----------|------------|
| [`apps/telegram-shop/README.md`](apps/telegram-shop/README.md) | Запуск / обновление готового бота |
| [`deploy/remnawave/README.md`](deploy/remnawave/README.md) | Установка Panel + Node, DNS, SSL, бэкапы |
| [`docs/COMMANDS.md`](docs/COMMANDS.md) | Полная шпаргалка |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | Процесс разработки |
| [`archive/README.md`](archive/README.md) | Что лежит в `archive/` и почему |

---

## Лицензия

[MPL-2.0](LICENSE). Бот `remnawave-telegram-shop` распространяется под собственной лицензией (см. upstream).
