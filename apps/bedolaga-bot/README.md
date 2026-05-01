# apps/bedolaga-bot — [Bedolaga](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot)

Telegram-бот + Web API + Postgres + Redis для продажи VPN на **Remnawave 2.7+**. Официальная документация: [docs.bedolagam.ru](https://docs.bedolagam.ru).

Здесь только наш **docker-compose** (жёсткая привязка HTTP к `127.0.0.1`, без публикации БД) и скрипт для логотипа. Полный список переменных — в upstream [`.env.example`](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/blob/main/.env.example).

## Быстрый старт

1. Запусти **Docker Desktop** (на Mac) и дождись готовности (`docker info` без ошибки).
2. Скачай шаблон `.env` с upstream и **в редакторе** заполни минимум: `POSTGRES_PASSWORD`, `BOT_TOKEN`, `ADMIN_IDS`, `REMNAWAVE_API_URL`, `REMNAWAVE_API_KEY` (остальное — по [доке](https://docs.bedolagam.ru)).
3. Логотип: `bash scripts/fetch_assets.sh` (файл не в git).

```bash
cd apps/bedolaga-bot
curl -fsSL -o .env https://raw.githubusercontent.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/main/.env.example
bash scripts/fetch_assets.sh
docker compose pull
docker compose up -d
docker compose logs -f bot
```

После `curl` **обязательно** отредактируй `.env` — иначе бот не подключится ни к Telegram, ни к панели.

Из корня репозитория: `make bot-up` (проверяет `.env` и при необходимости качает `vpn_logo.png`).

Образ: `ghcr.io/bedolaga-dev/remnawave-bedolaga-telegram-bot:latest` (linux/amd64, linux/arm64).

## Логи в файлах

Папка `./logs` смонтирована в контейнер как `/app/logs` — **файловые логи приложения** лежат на хосте в `apps/bedolaga-bot/logs/`. Дополнительно смотри `docker compose logs -f bot`.

## Безопасность (DDoS, сканирование портов, перебор)

Ни один compose **не отменяет DDoS на уровне сети** — нужен хостинг с фильтрацией, Cloudflare / WAF при публикации веба, лимиты у провайдера.

Что даёт **наш** `docker-compose.yml` по сравнению с дефолтным upstream:

| Угроза | Что сделано |
|--------|-------------|
| Сканирование интернета на открытый Postgres/Redis | Порты **не** проброшены на хост — доступ только из сети `bot_network` между контейнерами. |
| Перебор `WEB_API_DEFAULT_TOKEN` / HTTP по API | Порт **8080** проброшен как **`127.0.0.1:8080:8080`** — с интернета до API **не достучаться**, только с того же сервера (или через SSH-туннель). |
| Публикация API/вебхуков наружу | Подними **Caddy/nginx** на `443`, проксируй на `http://127.0.0.1:8080`, включи TLS и (по желанию) `rate_limit` / fail2ban на уровне прокси. |
| Слабый пароль БД / токены | Задай длинный случайный `POSTGRES_PASSWORD`, уникальный `REMNAWAVE_API_KEY`, сильный `BOT_TOKEN`. В `.env` не оставляй значения из примеров. |
| Встроенный Web API бота | В upstream по умолчанию `WEB_API_ENABLED=false` — **не включай** API без необходимости. Если включил — задай длинный `WEB_API_DEFAULT_TOKEN` и оставь bind на `127.0.0.1` + reverse proxy с TLS. |
| Личный кабинет (Cabinet) | См. [bedolaga-cabinet](https://github.com/BEDOLAGA-DEV/bedolaga-cabinet) и доку: отдельный домен, `CABINET_JWT_SECRET`, CORS, HTTPS. |

Панель Remnawave из этого репо (`deploy/remnawave/panel`): приложения в Docker-сети без проброса на хост, наружу — только **Caddy 80/443** — та же идея изоляции, что и у бота на `127.0.0.1:8080`.

## Обновление образа

```bash
cd apps/bedolaga-bot
docker compose pull
docker compose down && docker compose up -d
```

## Связка с панелью на одном хосте

Upstream предлагает `docker-compose.local.yml` с сетью `remnawave-network`. Если панель и бот на одной машине и нужен прямой доступ бота к `http://remnawave:3000`, объединяй сети по [доке Bedolaga](https://docs.bedolagam.ru) / файлу `docker-compose.local.yml` в upstream (внешняя сеть `remnawave-network`).

## Bedolaga Cabinet (веб-кабинет)

Официально: [Установка Cabinet](https://docs.bedolagam.ru/cabinet/setup), репозиторий [bedolaga-cabinet](https://github.com/BEDOLAGA-DEV/bedolaga-cabinet).

В этом каталоге добавлен **опциональный** профиль Compose: фронт кабинета + Caddy на **80/443** (на том же хосте, что и бот). Панель Remnawave при этом может быть на другом сервере — бот уже ходит в неё по `REMNAWAVE_API_URL`.

### 1) DNS и BotFather

- Запись **A/AAAA** для кабинета (например `cabinet.example.com`) → **IP сервера бота**.
- В **BotFather** → ваш бот → **Bot Settings → Domain** — укажите тот же домен (см. доку).

### 2) Переменные в `.env` бота

Добавьте и перезапустите бота (`docker compose up -d`):

```env
CABINET_ENABLED=true
CABINET_URL=https://cabinet.example.com
CABINET_JWT_SECRET=сгенерируйте_openssl_rand_hex_32
CABINET_ALLOWED_ORIGINS=https://cabinet.example.com

WEB_API_ENABLED=true
WEB_API_DEFAULT_TOKEN=длинный_случайный_токен_для_API
```

`CABINET_ALLOWED_ORIGINS` и `CABINET_URL` должны совпадать с публичным URL кабинета (схема `https`, без хвостового `/` в URL для CORS обычно как в доке).

### 3) Caddyfile

```bash
cp caddy/Cabinetfile.example caddy/Cabinetfile
# отредактируйте https://cabinet.example.com → ваш домен
```

### 4) Запуск

**Выделенный сервер только под бота** (на `:80`/`:443` никто не слушает):

```bash
docker compose pull
cp caddy/Cabinetfile.example caddy/Cabinetfile
# отредактировать домен в Cabinetfile
docker compose --profile cabinet --profile cabinet-caddy up -d
```

**Тот же VPS, что и Remnawave** (уже есть контейнер `caddy` панели на 80/443) — **второй Caddy не поднимаем**:

```bash
docker rm -f bedolaga_cabinet_caddy 2>/dev/null || true
docker compose pull
docker compose --profile cabinet up -d
```

Дальше в **Caddy панели** (`/opt/remnawave/caddy/Caddyfile`) добавьте блок для кабинета — см. шаблон в репозитории `deploy/remnawave/panel/caddy/Caddyfile` (сайт `cabinet.32-network.online`). Подключите контейнер `caddy` к сети бота и перезагрузите Caddy:

```bash
docker network ls | grep bedolaga
docker network connect bedolaga-bot_bot_network caddy
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

Имя сети может отличаться (папка проекта compose): смотрите колонку **NAME** в `docker network ls`.

Проверка: `curl -sI https://cabinet.example.com/` и `curl -sI https://cabinet.example.com/api/health`.

На выделенном сервере под бота должны быть открыты **80/tcp** и **443/tcp**. На общем сервере с панелью порты уже заняты панельным Caddy — это нормально.

## Ссылки

- Репозиторий: <https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot>
- Документация: <https://docs.bedolagam.ru>
- Remnawave: <https://docs.rw/>
- Security policy upstream: <https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/blob/main/SECURITY.md>
