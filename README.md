<div align="center">

# VPN Product — Remnawave + Bedolaga

**Коммерческий VPN-сервис:** Remnawave Panel + Remnawave Node + Telegram-бот **[Bedolaga](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot)** (продажи, баланс, платежи, веб API). Ставится на 2–3 серверах; в репозитории — усиленный `docker-compose` (Postgres/Redis без публикации наружу, HTTP API только на `127.0.0.1`).

[![CI](https://img.shields.io/github/actions/workflow/status/bini69-oi/vpn-work-xray/ci.yml?style=flat-square&label=CI)](https://github.com/bini69-oi/vpn-work-xray/actions)
[![Remnawave](https://img.shields.io/badge/Remnawave-Panel%20%2B%20Node-blue?style=flat-square)](https://docs.rw)
[![Bot](https://img.shields.io/badge/Bot-Bedolaga-26A5E4?style=flat-square&logo=telegram&logoColor=white)](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot)
[![License](https://img.shields.io/badge/License-MPL--2.0-green?style=flat-square)](LICENSE)

</div>

---

## Что это

- [**Remnawave Panel + Node**](deploy/remnawave/README.md) — официальный Docker-стек Remnawave ([docs.rw](https://docs.rw/)). Панель управляет пользователями и подписками, нода шифрует трафик (VLESS / REALITY через встроенный Xray-core).
- [**Telegram-бот Bedolaga**](apps/bedolaga-bot/README.md) — образ `ghcr.io/bedolaga-dev/remnawave-bedolaga-telegram-bot`, Postgres, Redis; интеграция с Remnawave API, множество платёжек, рефералка, админка в Telegram, опциональный веб-кабинет ([документация](https://docs.bedolagam.ru)).
- **2–3 сервера** без лишней обвязки: Panel, Node, бот (бот можно поставить рядом с Panel).

> **История.** Раньше здесь жил Go-сервис `vpn-productd` + форк Xray-core + Mini App + собственный Python-бот; затем бот Jolymmiels `remnawave-telegram-shop` (см. [`archive/telegram-shop-jolymmiels/`](archive/telegram-shop-jolymmiels/README.md)). Сейчас ядро — официальный Remnawave, продажи — **Bedolaga**.

---

## Архитектура

```
 ┌─────────────────────────────┐        ┌──────────────────────────────┐
 │  Сервер 1 — Remnawave Panel │        │  Сервер 3 (или рядом с 1)    │
 │  ┌───────────────────────┐  │◀──────▶│  Bedolaga bot + PG + Redis   │
 │  │ remnawave (REST API)  │  │ HTTPS  │  docker compose up -d        │
 │  │ Postgres  Redis       │  │        │  apps/bedolaga-bot/          │
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

### 3. Telegram-бот Bedolaga (рядом с Panel или отдельный сервер)

```bash
cd apps/bedolaga-bot
curl -fsSL -o .env https://raw.githubusercontent.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/main/.env.example
# отредактируй .env: POSTGRES_PASSWORD, BOT_TOKEN, ADMIN_IDS,
#   REMNAWAVE_API_URL, REMNAWAVE_API_KEY, платёжки и т.д. (см. docs.bedolagam.ru)

bash scripts/fetch_assets.sh   # vpn_logo.png
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
make bot-assets   # vpn_logo.png
```

---

## Что настраивается в `.env` бота

Шаблон на **1000+ строк** — скачивай с upstream (см. быстрый старт выше). Кратко:

| Переменная | Что это |
|---|---|
| `BOT_TOKEN` | Токен из @BotFather |
| `ADMIN_IDS` | Telegram ID админов (через запятую) |
| `POSTGRES_PASSWORD` | Сильный пароль БД бота |
| `REMNAWAVE_API_URL` | `https://panel.example.com` |
| `REMNAWAVE_API_KEY` | Ключ API панели (или другой `REMNAWAVE_AUTH_TYPE` по доке Bedolaga) |
| `WEB_API_ENABLED` | Оставь `false`, пока не нужен HTTP API; при `true` задай `WEB_API_DEFAULT_TOKEN` и отдавай наружу только через HTTPS reverse proxy |

Полный справочник: [upstream `.env.example`](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/blob/main/.env.example) и [docs.bedolagam.ru](https://docs.bedolagam.ru).

**Безопасность:** в [`apps/bedolaga-bot/docker-compose.yml`](apps/bedolaga-bot/docker-compose.yml) порт **8080** — только **`127.0.0.1`**; Postgres и Redis **не** проброшены на хост. Детали — [`apps/bedolaga-bot/README.md`](apps/bedolaga-bot/README.md).

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
| Логотип для бота | `make bot-assets` |
| Secret-scan | `make secret-scan` |
| Локальный прогон CI (secret-scan + `docker compose config`) | `make verify` |
| Установить git-хуки | `bash scripts/install_git_hooks.sh` |

Подробный справочник по установке Panel/Node, бэкапам и отладке — [`docs/COMMANDS.md`](docs/COMMANDS.md).

---

## Структура репозитория

| Путь | Назначение |
|------|------------|
| [`apps/bedolaga-bot/`](apps/bedolaga-bot/README.md) | Bedolaga: `docker-compose.yml` (localhost API, без публикации БД) + скрипт ассетов |
| [`deploy/remnawave/`](deploy/remnawave/README.md) | Docker Compose + `install_*.sh` для Panel / Node + Caddy + systemd-бэкап |
| [`deploy/backups/`](deploy/backups/) | Скрипты бэкапа Postgres Remnawave |
| [`docs/`](docs/) | [COMMANDS.md](docs/COMMANDS.md), [CONTRIBUTING.md](docs/CONTRIBUTING.md) |
| [`scripts/`](scripts/) | `secret_scan.py`, git-хуки (`pre-commit`/`pre-push`) |
| [`archive/`](archive/README.md) | `vpn-productd/`, `vpn-telegram-bot-custom/`, `telegram-shop-jolymmiels/`, `telegram-bot-legacy/`, `telegram-miniapp/` |

---

## CI / качество

GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)):

1. **`secret-scan`** — `scripts/secret_scan.py` ищет утечки токенов/ключей.
2. **`compose-lint`** — `docker compose config` для [`apps/bedolaga-bot/docker-compose.yml`](apps/bedolaga-bot/docker-compose.yml) с [`apps/bedolaga-bot/.env.ci`](apps/bedolaga-bot/.env.ci).

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
| [`apps/bedolaga-bot/README.md`](apps/bedolaga-bot/README.md) | Запуск Bedolaga, безопасность портов, логи |
| [`deploy/remnawave/README.md`](deploy/remnawave/README.md) | Установка Panel + Node, DNS, SSL, бэкапы |
| [`docs/COMMANDS.md`](docs/COMMANDS.md) | Полная шпаргалка |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | Процесс разработки |
| [`archive/README.md`](archive/README.md) | Что лежит в `archive/` и почему |

---

## Лицензия

[MPL-2.0](LICENSE). Bedolaga — лицензия [MIT](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/blob/main/LICENSE) (см. upstream).
