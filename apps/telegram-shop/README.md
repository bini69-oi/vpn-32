# apps/telegram-shop

Готовый Telegram-бот для продажи подписок **Remnawave** — [Jolymmiels/remnawave-telegram-shop](https://github.com/Jolymmiels/remnawave-telegram-shop).

Здесь лежит только наша обвязка под запуск: `docker-compose.yaml`, `.env.sample` с RUB-ценами и папка `translations/` для кастомных переводов.

## Что умеет бот

- Продажа подписок (1 / 3 / 6 / 12 мес.)
- Платежи: YooKassa, CryptoPay, Telegram Stars, Tribute
- Триал, реф-программа, промокоды
- Авто-уведомления за 3 дня до окончания
- Выбор Internal / External Squad через `SQUAD_UUIDS` / `EXTERNAL_SQUAD_UUID`
- Мультиязычность (ru / en) через файлы в `translations/`
- `/sync` — синхронизация пользователей с Remnawave Panel
- Healthcheck: `GET /healthcheck` на `HEALTH_CHECK_PORT`

## Архитектура (2–3 сервера)

```
┌─────────────────┐        ┌──────────────────────┐        ┌──────────────┐
│ Remnawave Panel │◀──────▶│  telegram-shop bot   │───────▶│  Telegram    │
│ (API + PG)      │  HTTPS │  (этот docker-compose)│        │   Bot API    │
└────────┬────────┘        └──────────────────────┘        └──────────────┘
         │ xtls/reality
         ▼
┌─────────────────┐
│ Remnawave Node  │  ← VPN-трафик (VLESS/REALITY), см. deploy/remnawave/node
└─────────────────┘
```

Бот обращается только к Remnawave Panel по HTTPS. Его можно поднять:

- на том же сервере, что и Panel (самый простой вариант)
- на отдельной VPS (Panel на одном, Node на другом, бот на третьем)

## Быстрый старт

```bash
cd apps/telegram-shop
cp .env.sample .env
# отредактируй .env — минимум:
#   TELEGRAM_TOKEN, ADMIN_TELEGRAM_ID,
#   REMNAWAVE_URL, REMNAWAVE_TOKEN,
#   PRICE_*, STARS_PRICE_*

docker compose pull
docker compose up -d
docker compose logs -f bot
```

Или из корня репозитория:

```bash
make bot-up       # up -d
make bot-logs     # логи
make bot-pull     # обновить образ и перезапустить
make bot-down     # stop + remove
```

## Обновление

```bash
cd apps/telegram-shop
docker compose pull
docker compose down && docker compose up -d
```

## Переводы / кастом текстов

Файлы переводов монтируются в контейнер из `./translations`. Чтобы поменять тексты — положи сюда файлы языков (см. исходник upstream-бота) и перезапусти контейнер.

## Где взять значения

- `TELEGRAM_TOKEN` — [@BotFather](https://t.me/BotFather) → `/newbot` → скопируй токен.
- `ADMIN_TELEGRAM_ID` — напиши боту [@userinfobot](https://t.me/userinfobot), получи свой `id`.
- `REMNAWAVE_URL` / `REMNAWAVE_TOKEN` — в админке Remnawave Panel: **API Tokens → Create**.
- `SQUAD_UUIDS` — в Remnawave Panel: **Internal Squads → копируй UUID нужных**.

## Ссылки

- Upstream-репозиторий: <https://github.com/Jolymmiels/remnawave-telegram-shop>
- Документация: <https://remnawave-telegram-shop-bot-doc.vercel.app/>
- Remnawave Panel: <https://docs.rw/>
