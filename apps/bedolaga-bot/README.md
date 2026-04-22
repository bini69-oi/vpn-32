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

Панель Remnawave из этого репо (`deploy/remnawave/panel`) уже слушает приложение на **127.0.0.1**, наружу — только **Caddy 80/443** — это правильная схема и для панели, и для бота.

## Обновление образа

```bash
cd apps/bedolaga-bot
docker compose pull
docker compose down && docker compose up -d
```

## Связка с панелью на одном хосте

Upstream предлагает `docker-compose.local.yml` с сетью `remnawave-network`. Если панель и бот на одной машине и нужен прямой доступ бота к `http://remnawave:3000`, объединяй сети по [доке Bedolaga](https://docs.bedolagam.ru) / файлу `docker-compose.local.yml` в upstream (внешняя сеть `remnawave-network`).

## Ссылки

- Репозиторий: <https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot>
- Документация: <https://docs.bedolagam.ru>
- Remnawave: <https://docs.rw/>
- Security policy upstream: <https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot/blob/main/SECURITY.md>
