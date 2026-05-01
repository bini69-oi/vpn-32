<div align="center">

# VPN Product — Remnawave + Bedolaga

**Коммерческий VPN-сервис:** Remnawave Panel + Remnawave Node + Telegram-бот **[Bedolaga](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot)** (продажи, баланс, платежи, веб API). Ставится на 2–3 серверах; в репозитории — усиленный `docker-compose` панели: Postgres/Redis и приложения **без** проброса портов на хост, наружу только **Caddy :80/:443**.

[![CI](https://img.shields.io/github/actions/workflow/status/bini69-oi/vpn-32/ci.yml?style=flat-square&label=CI)](https://github.com/bini69-oi/vpn-32/actions)
[![Remnawave](https://img.shields.io/badge/Remnawave-Panel%20%2B%20Node-blue?style=flat-square)](https://docs.rw)
[![Bot](https://img.shields.io/badge/Bot-Bedolaga-26A5E4?style=flat-square&logo=telegram&logoColor=white)](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot)
[![License](https://img.shields.io/badge/License-MPL--2.0-green?style=flat-square)](LICENSE)

</div>

---

## Что это

- [**Remnawave Panel + Node**](deploy/remnawave/README.md) — официальный Docker-стек Remnawave ([docs.rw](https://docs.rw/)). Панель управляет пользователями и подписками, нода шифрует трафик (VLESS / REALITY через встроенный Xray-core).
- [**Telegram-бот Bedolaga**](apps/bedolaga-bot/README.md) — образ `ghcr.io/bedolaga-dev/remnawave-bedolaga-telegram-bot`, Postgres, Redis; интеграция с Remnawave API, множество платёжек, рефералка, админка в Telegram, опциональный веб-кабинет ([документация](https://docs.bedolagam.ru)).
- **2–3 сервера** без лишней обвязки: Panel, Node, бот (бот можно поставить рядом с Panel).
- [**Xray Checker**](deploy/xray-checker/README.md) — опциональный мониторинг доступности прокси и метрики; upstream: [kutovoys/xray-checker](https://github.com/kutovoys/xray-checker).

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

## Быстрый старт (минимум ручных правок)

Шаблоны заточены под зону **`32-network.online`** (Reg.ru), без привязки к конкретным IP в репозитории:

| Имя | Роль |
|-----|------|
| **`panel.32-network.online`** | панель Remnawave — A `panel` на **IP VPS панели** |
| **`sub.32-network.online`** | subscription — A `sub` на **тот же IP**, что и панель |
| **`32-network.online`**, **`www`** | при необходимости другой сайт (корень/`www` в DNS не обязаны совпадать с панелью) |

Для **другой** зоны задайте `PANEL_FQDN` / `SUB_FQDN` ниже и поправьте `deploy/remnawave/panel/.env.example` + `caddy/Caddyfile`.

**До запуска:** A/AAAA для панели и `sub` указывают на **IP сервера панели**. За **Cloudflare** (orange cloud) — SSL **Full (strict)** к origin.

Подробная пошаговая инструкция (что вводить в браузере при регистрации, API-токен, создание ноды в UI, `.env` на ноде): **[`deploy/remnawave/README.md` — раздел «Пошагово…»](deploy/remnawave/README.md#remnawave-quickstart-full)**.

### Переменные (скопируйте блок и поменяйте только то, что нужно)

```bash
export REPO_URL="${REPO_URL:-https://github.com/bini69-oi/vpn-32.git}"
# Панель: два FQDN (как в DNS)
export PANEL_FQDN="${PANEL_FQDN:-panel.32-network.online}"
export SUB_FQDN="${SUB_FQDN:-sub.32-network.online}"
# Нода: порт и секрет из UI панели (Management → Nodes → создать ноду)
export NODE_PORT="${NODE_PORT:-2222}"
export NODE_PUBLIC_IP="${NODE_PUBLIC_IP:-ЗАМЕНИТЕ_НА_ПУБЛИЧНЫЙ_IP_НОДЫ}"
export SECRET_KEY="${SECRET_KEY:-ЗАМЕНИТЕ_НА_SECRET_KEY_ИЗ_UI}"
```

### 1. Сервер панели (один заход под `root`)

```bash
apt-get update -qq && apt-get install -y git ca-certificates curl
git clone "${REPO_URL}" /root/vpn-32 && cd /root/vpn-32
sudo bash deploy/remnawave/scripts/install_panel.sh "${PANEL_FQDN}" "${SUB_FQDN}"
sudo cp /root/vpn-32/deploy/remnawave/panel/caddy/Caddyfile /opt/remnawave/caddy/Caddyfile
cd /opt/remnawave && docker compose restart caddy
```

Скрипт с двумя аргументами сам пропишет домены и JWT; в `.env` появится **случайный** `REMNAWAVE_API_TOKEN` — его **обязательно** заменить на токен из панели (иначе `https://${SUB_FQDN}` даст 502):

1. Откройте `https://${PANEL_FQDN}` → зарегистрируйтесь (первый пользователь = super-admin).
2. **Settings → API Tokens** → создайте токен.
3. На сервере:

```bash
sudoedit /opt/remnawave/.env
# строка REMNAWAVE_API_TOKEN=... — вставить токен из UI
cd /opt/remnawave && docker compose up -d
curl -sI "https://${PANEL_FQDN}/" | head -5
curl -sI "https://${SUB_FQDN}/" | head -5
```

**Cloudflare origin** (только после orange cloud для обоих доменов):

```bash
cd /root/vpn-32
sudo systemctl enable --now remnawave-cloudflare-origin.service remnawave-cloudflare-origin.timer
# опционально UFW на панели (сначала прочитайте deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md):
# sudo CONFIRM=1 ADMIN_SSH_CIDR=ВАШ_IP/32 bash deploy/remnawave/scripts/harden_ufw_panel.sh
```

Без двух аргументов к `install_panel.sh` можно править только `/opt/remnawave/.env` и Caddy вручную — см. **[пошаговую инструкцию](deploy/remnawave/README.md#remnawave-quickstart-full)** и раздел «Panel установка» в [`deploy/remnawave/README.md`](deploy/remnawave/README.md).

### 2. Сервер ноды (один заход под `root`)

В UI панели при создании ноды укажите **публичный IP ноды** = `NODE_PUBLIC_IP` и **Node Port** = `NODE_PORT`, затем скопируйте `SECRET_KEY` в переменную окружения на ноде (см. блок переменных выше).

```bash
apt-get update -qq && apt-get install -y git ca-certificates curl
git clone "${REPO_URL}" /root/vpn-32 && cd /root/vpn-32
sudo bash deploy/remnawave/scripts/install_node.sh
sudo tee /opt/remnanode/.env >/dev/null <<EOF
NODE_PORT=${NODE_PORT}
SECRET_KEY="${SECRET_KEY}"
EOF
sudo chmod 0600 /opt/remnanode/.env
cd /opt/remnanode && docker compose up -d
docker compose logs --tail=30
```

На **облачном фаерволе** (Timeweb и т.п.) откройте **TCP/UDP для `NODE_PORT`** и для **портов инбаундов** из профиля (например Shadowsocks на `1234` — см. профиль в панели). На хосте при необходимости: `CONFIRM=1 NODE_PORT=... bash deploy/remnawave/scripts/harden_ufw_node.sh` — [`deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md`](deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md).

### 3. Выдать подписку пользователю

В панели: **хост (нода + профиль)** → **пользователь** → скопировать **subscription URL** (домен из `SUB_PUBLIC_DOMAIN`, у вас это `sub.32-network.online`). Клиент: обновить подписку по ссылке.

### 4. Telegram-бот Bedolaga (рядом с Panel или отдельный сервер)

Сначала отредактируй `.env` после скачивания (см. [apps/bedolaga-bot/README.md](apps/bedolaga-bot/README.md)).

```bash
cd apps/bedolaga-bot
curl -fsSL -o .env https://raw.githubusercontent.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/main/.env.example
bash scripts/fetch_assets.sh
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
| [`deploy/remnawave/`](deploy/remnawave/README.md#remnawave-quickstart-full) | Пошагово: панель, UI, нода + Compose, Caddy, `install_*.sh`, systemd-бэкап |
| [`deploy/xray-checker/`](deploy/xray-checker/README.md) | Docker Compose для [Xray Checker](https://github.com/kutovoys/xray-checker) (подписка → проверки, UI на `127.0.0.1:2112`) |
| [`deploy/backups/`](deploy/backups/) | Скрипты бэкапа Postgres Remnawave |
| [`docs/`](docs/) | [COMMANDS.md](docs/COMMANDS.md), [CONTRIBUTING.md](docs/CONTRIBUTING.md) |
| [`scripts/`](scripts/) | `secret_scan.py`, git-хуки (`pre-commit`/`pre-push`) |
| [`archive/`](archive/README.md) | `vpn-productd/`, `vpn-telegram-bot-custom/`, `telegram-shop-jolymmiels/`, `telegram-bot-legacy/`, `telegram-miniapp/` |

---

## CI / качество

GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)):

1. **`secret-scan`** — `scripts/secret_scan.py` ищет утечки токенов/ключей.
2. **`compose-lint`** — `docker compose config` для [`apps/bedolaga-bot`](apps/bedolaga-bot/docker-compose.yml) (`.env.ci`) и [`deploy/xray-checker`](deploy/xray-checker/docker-compose.yml) (`.env.example`).

Собственный Python-бот со всеми 205 тестами (ruff + mypy + pytest --cov ≥ 80 %) лежит в [`archive/vpn-telegram-bot-custom/`](archive/vpn-telegram-bot-custom/). Если захочешь вернуться к своему боту — перенеси обратно в `apps/` и восстанови `bot-quality` job из истории `.github/workflows/ci.yml`.

---

## Git hooks

```bash
bash scripts/install_git_hooks.sh
```

- `pre-commit`: `make secret-scan`.
- `pre-push`: `make verify` (secret-scan + compose config для бота и xray-checker).

---

## Документация

| Документ | Что внутри |
|----------|------------|
| [`apps/bedolaga-bot/README.md`](apps/bedolaga-bot/README.md) | Запуск Bedolaga, безопасность портов, логи |
| [`deploy/remnawave/README.md`](deploy/remnawave/README.md#remnawave-quickstart-full) | Пошаговая установка (команды + UI), DNS, SSL, бэкапы |
| [`deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md`](deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md) | DDoS/брутфорс: Cloudflare + UFW (Wirefall), SSH |
| [`deploy/xray-checker/README.md`](deploy/xray-checker/README.md) | Запуск мониторинга, ссылка на [GitHub](https://github.com/kutovoys/xray-checker) |
| [`docs/COMMANDS.md`](docs/COMMANDS.md) | Полная шпаргалка |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | Процесс разработки |
| [`archive/README.md`](archive/README.md) | Что лежит в `archive/` и почему |

---

## Лицензия

[MPL-2.0](LICENSE). Bedolaga — лицензия [MIT](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/blob/main/LICENSE) (см. upstream).
