<div align="center">

# VPN-стек: Remnawave + Bedolaga

**VPN-32:** многокомпонентное развёртывание VPN-панели и ноды на базе upstream **Remnawave** (Panel + Node, Xray-core), плюс Telegram-бот **[Bedolaga](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot)** для продаж, баланса, платежей и опционального веб-API.

В репозитории — не собственная реализация протокола VPN, а **оркестрация и эксплуатация**: усиленный `docker-compose` (Postgres/Redis и сервисы без лишнего проброса портов на хост), наружу по умолчанию **Caddy :80/:443**, скрипты установки панели и ноды, CI (secret-scan, проверка compose), документация по DNS/SSL и усилению периметра.

**Кратко о содержимом репозитория**

- Compose и Caddy для Remnawave Panel; сценарии `install_panel.sh` / `install_node.sh`.
- Обвязка **Bedolaga** с ограничением Web API на `127.0.0.1` и без публикации БД наружу.
- Опционально: **Xray Checker**, скрипты бэкапа Postgres, git-хуки и `secret_scan.py`.

Типовая топология: **2–3 VPS** (Panel, Node, бот — последний часто рядом с Panel).

[![CI](https://img.shields.io/github/actions/workflow/status/bini69-oi/vpn-32/ci.yml?style=flat-square&label=CI)](https://github.com/bini69-oi/vpn-32/actions)
[![Remnawave](https://img.shields.io/badge/Remnawave-Panel%20%2B%20Node-blue?style=flat-square)](https://docs.rw)
[![Bot](https://img.shields.io/badge/Bot-Bedolaga-26A5E4?style=flat-square&logo=telegram&logoColor=white)](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot)
[![License](https://img.shields.io/badge/License-MPL--2.0-green?style=flat-square)](LICENSE)

</div>

---

## Компоненты

- [**Remnawave Panel + Node**](deploy/remnawave/README.md) — официальный Docker-стек ([docs.rw](https://docs.rw/)): панель (пользователи, подписки, REST API), нода — трафик через встроенный Xray-core (VLESS / REALITY).
- [**Telegram-бот Bedolaga**](apps/bedolaga-bot/README.md) — образ `ghcr.io/bedolaga-dev/remnawave-bedolaga-telegram-bot`, Postgres, Redis; интеграция с Remnawave API, платежи, реферальная логика, админка в Telegram, опциональный веб-кабинет — [документация Bedolaga](https://docs.bedolagam.ru).
- [**Xray Checker**](deploy/xray-checker/README.md) — опциональный мониторинг доступности прокси и метрики; upstream: [kutovoys/xray-checker](https://github.com/kutovoys/xray-checker).

### Эволюция репозитория

Ранее в монорепозитории находились Go-сервис `vpn-productd`, форк Xray-core, Mini App и собственный Python-бот; затем использовался бот Jolymmiels [`remnawave-telegram-shop`](archive/telegram-shop-jolymmiels/README.md). **Текущее ядро** — официальный Remnawave; **продажи и бот** — Bedolaga. Исторические артефакты собраны в [`archive/`](archive/README.md).

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

Шифрование пользовательского трафика выполняет **Remnawave Node** (Xray-core, VLESS + REALITY); отдельная реализация VPN-ядра в этом репозитории не требуется.

---

## Быстрый старт (минимум ручных правок)

**Предпосылки:** VPS с Docker, настроенные DNS-записи на IP панели, доступ по SSH (для шагов ниже — пользователь с правами `root` на серверах панели и ноды). Детали регистрации в UI панели, выпуска API-токена и создания ноды вынесены в отдельный документ — см. ссылку в конце абзаца.

Шаблоны ориентированы на зону **`32-network.online`** (Reg.ru); конкретные IP в репозиторий не зашиты.

| Имя | Роль |
|-----|------|
| **`panel.32-network.online`** | панель Remnawave — A `panel` на **IP VPS панели** |
| **`sub.32-network.online`** | subscription — A `sub` на **тот же IP**, что и панель |
| **`32-network.online`**, **`www`** | при необходимости отдельный сайт (корень/`www` в DNS не обязаны совпадать с панелью) |

Для **другой** DNS-зоны задайте `PANEL_FQDN` / `SUB_FQDN` ниже и скорректируйте `deploy/remnawave/panel/.env.example` и `caddy/Caddyfile`.

**Перед запуском:** A/AAAA для панели и `sub` указывают на **IP сервера панели**. За **Cloudflare** (orange cloud) у origin — режим SSL **Full (strict)**.

Пошаговый сценарий (регистрация в веб-интерфейсе, API-токен, нода, `.env` на ноде): **[`deploy/remnawave/README.md` — «Пошагово…»](deploy/remnawave/README.md#remnawave-quickstart-full)**.

### Переменные окружения (скопируйте блок и измените значения по месту)

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

### 1. Сервер панели (один сеанс под `root`)

```bash
apt-get update -qq && apt-get install -y git ca-certificates curl
git clone "${REPO_URL}" /root/vpn-32 && cd /root/vpn-32
sudo bash deploy/remnawave/scripts/install_panel.sh "${PANEL_FQDN}" "${SUB_FQDN}"
sudo cp /root/vpn-32/deploy/remnawave/panel/caddy/Caddyfile /opt/remnawave/caddy/Caddyfile
cd /opt/remnawave && docker compose restart caddy
```

При вызове скрипта с двумя аргументами прописываются домены и JWT; в `.env` появляется **случайный** `REMNAWAVE_API_TOKEN` — его нужно **заменить** на токен из панели (иначе `https://${SUB_FQDN}` отдаст 502):

1. Откройте `https://${PANEL_FQDN}`, завершите регистрацию (первый пользователь — super-admin).
2. **Settings → API Tokens** — создайте токен.
3. На сервере:

```bash
sudoedit /opt/remnawave/.env
# REMNAWAVE_API_TOKEN=... — значение из UI
cd /opt/remnawave && docker compose up -d
curl -sI "https://${PANEL_FQDN}/" | head -5
curl -sI "https://${SUB_FQDN}/" | head -5
```

**Cloudflare origin** (после включения orange cloud для обоих доменов):

```bash
cd /root/vpn-32
sudo systemctl enable --now remnawave-cloudflare-origin.service remnawave-cloudflare-origin.timer
# опционально UFW на панели (сначала: deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md):
# sudo CONFIRM=1 ADMIN_SSH_CIDR=ВАШ_IP/32 bash deploy/remnawave/scripts/harden_ufw_panel.sh
```

Если `install_panel.sh` вызывается без двух аргументов, правки — только в `/opt/remnawave/.env` и Caddy вручную; см. **[пошаговую инструкцию](deploy/remnawave/README.md#remnawave-quickstart-full)** и раздел «Panel установка» в [`deploy/remnawave/README.md`](deploy/remnawave/README.md).

### 2. Сервер ноды (один сеанс под `root`)

В UI панели при создании ноды укажите **публичный IP ноды** (`NODE_PUBLIC_IP`) и **Node Port** (`NODE_PORT`), затем перенесите `SECRET_KEY` в переменные окружения на ноде (см. блок выше).

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

На **облачном фаерволе** откройте **TCP/UDP** для `NODE_PORT` и для портов инбаундов из профиля (например Shadowsocks на `1234` — см. профиль в панели). На хосте при необходимости: `CONFIRM=1 NODE_PORT=... bash deploy/remnawave/scripts/harden_ufw_node.sh` — [`deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md`](deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md).

### 3. Выдача подписки пользователю

В панели: **хост (нода + профиль)** → **пользователь** → **subscription URL** (домен из `SUB_PUBLIC_DOMAIN`, в шаблоне — `sub.32-network.online`). В клиенте обновите подписку по ссылке.

### 4. Telegram-бот Bedolaga (рядом с Panel или отдельный сервер)

После получения шаблона `.env` отредактируйте его (см. [apps/bedolaga-bot/README.md](apps/bedolaga-bot/README.md)).

```bash
cd apps/bedolaga-bot
curl -fsSL -o .env https://raw.githubusercontent.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/main/.env.example
bash scripts/fetch_assets.sh
docker compose pull
docker compose up -d
docker compose logs -f bot
```

Из корня репозитория:

```bash
make bot-up       # up -d
make bot-logs     # tail логов
make bot-pull     # обновление образа
make bot-down     # stop + rm
make bot-assets   # vpn_logo.png
```

---

## Переменные `.env` бота (выдержка)

Полный шаблон (**1000+ строк**) загружается с upstream (см. быстрый старт). Ниже — типовые ключи:

| Переменная | Описание |
|---|---|
| `BOT_TOKEN` | Токен от @BotFather |
| `ADMIN_IDS` | Telegram ID администраторов (через запятую) |
| `POSTGRES_PASSWORD` | Пароль БД бота |
| `REMNAWAVE_API_URL` | Базовый URL панели, например `https://panel.example.com` |
| `REMNAWAVE_API_KEY` | Ключ API панели (либо иной `REMNAWAVE_AUTH_TYPE` по документации Bedolaga) |
| `WEB_API_ENABLED` | До появления необходимости в HTTP API оставьте `false`; при `true` задайте `WEB_API_DEFAULT_TOKEN` и публикуйте endpoint только за HTTPS reverse proxy |

Полный перечень: [upstream `.env.example`](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/blob/main/.env.example) и [docs.bedolagam.ru](https://docs.bedolagam.ru).

**Периметр:** в [`apps/bedolaga-bot/docker-compose.yml`](apps/bedolaga-bot/docker-compose.yml) порт **8080** привязан к **`127.0.0.1`**; Postgres и Redis на хост не пробрасываются. Подробнее — [`apps/bedolaga-bot/README.md`](apps/bedolaga-bot/README.md).

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

Расширенная шпаргалка: установка Panel/Node, бэкапы, отладка — [`docs/COMMANDS.md`](docs/COMMANDS.md).

---

## Структура репозитория

| Путь | Назначение |
|------|------------|
| [`apps/bedolaga-bot/`](apps/bedolaga-bot/README.md) | Bedolaga: `docker-compose.yml` (API на localhost, БД не наружу) + скрипт ассетов |
| [`deploy/remnawave/`](deploy/remnawave/README.md#remnawave-quickstart-full) | Панель, UI, нода: Compose, Caddy, `install_*.sh`, systemd-бэкап |
| [`deploy/xray-checker/`](deploy/xray-checker/README.md) | Compose для [Xray Checker](https://github.com/kutovoys/xray-checker) (подписка → проверки, UI на `127.0.0.1:2112`) |
| [`deploy/backups/`](deploy/backups/) | Скрипты бэкапа Postgres Remnawave |
| [`docs/`](docs/) | [COMMANDS.md](docs/COMMANDS.md), [CONTRIBUTING.md](docs/CONTRIBUTING.md) |
| [`scripts/`](scripts/) | `secret_scan.py`, git-хуки (`pre-commit` / `pre-push`) |
| [`archive/`](archive/README.md) | `vpn-productd/`, `vpn-telegram-bot-custom/`, `telegram-shop-jolymmiels/`, `telegram-bot-legacy/`, `telegram-miniapp/` |

---

## CI / качество

GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)):

1. **`secret-scan`** — `scripts/secret_scan.py` (поиск утечек токенов и ключей).
2. **`compose-lint`** — `docker compose config` для [`apps/bedolaga-bot`](apps/bedolaga-bot/docker-compose.yml) (`.env.ci`) и [`deploy/xray-checker`](deploy/xray-checker/docker-compose.yml) (`.env.example`).

Историческая ветка развития: собственный Python-бот с набором тестов (ruff, mypy, pytest, покрытие ≥ 80 %) находится в [`archive/vpn-telegram-bot-custom/`](archive/vpn-telegram-bot-custom/). Вернуть его в активную разработку можно переносом в `apps/` и восстановлением job `bot-quality` из истории `.github/workflows/ci.yml`.

---

## Git hooks

```bash
bash scripts/install_git_hooks.sh
```

- `pre-commit`: `make secret-scan`.
- `pre-push`: `make verify` (secret-scan + `docker compose config` для бота и xray-checker).

---

## Документация

| Документ | Содержание |
|----------|------------|
| [`apps/bedolaga-bot/README.md`](apps/bedolaga-bot/README.md) | Запуск Bedolaga, схема портов, логи |
| [`deploy/remnawave/README.md`](deploy/remnawave/README.md#remnawave-quickstart-full) | Установка (команды и UI), DNS, SSL, бэкапы |
| [`deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md`](deploy/remnawave/docs/SECURITY_WIREFALL_CLOUDFLARE.md) | Cloudflare + UFW (Wirefall), SSH |
| [`deploy/xray-checker/README.md`](deploy/xray-checker/README.md) | Мониторинг, ссылка на [GitHub](https://github.com/kutovoys/xray-checker) |
| [`docs/COMMANDS.md`](docs/COMMANDS.md) | Полная шпаргалка по командам |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | Процесс разработки |
| [`archive/README.md`](archive/README.md) | Состав `archive/` и контекст |

---

## Лицензия

Код репозитория — [MPL-2.0](LICENSE). Bedolaga и прочие upstream-компоненты распространяются под [своими лицензиями](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/blob/main/LICENSE) (Bedolaga — MIT).
