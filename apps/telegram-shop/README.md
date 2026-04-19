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

## Рефералы, логи и статистика (бесплатный бот)

В `.env` включи рефералку: **`REFERRAL_DAYS`** > `0` (например `7`) — иначе кнопка рефералов не появится.

### Что видит пользователь в Telegram

В экране реферала текст один: **«Приглашено: N»** — это `COUNT(*)` по таблице `referral` для данного `referrer_id` ([`internal/handler/referral.go`](https://github.com/Jolymmiels/remnawave-telegram-shop/blob/main/internal/handler/referral.go)). Отдельной строки **«из них оплатили: M»** в UI **нет**.

Запись в `referral` создаётся только если новый пользователь **впервые** нажал `/start` со ссылкой вида `?start=ref_<telegram_id_пригласившего>` ([`internal/handler/start.go`](https://github.com/Jolymmiels/remnawave-telegram-shop/blob/main/internal/handler/start.go)).

### Кто из приглашённых оплатил

После успешной оплаты приглашённого бот начисляет дни пригласившему и выставляет **`referral.bonus_granted = true`** ([`internal/payment/payment.go`](https://github.com/Jolymmiels/remnawave-telegram-shop/blob/main/internal/payment/payment.go)). То есть:

- **пригласил по ссылке** — есть строка в `referral` с `bonus_granted = false`;
- **приглашённый реально оплатил** (и бонус выдан) — та же строка с `bonus_granted = true`.

### Логирование

Бот пишет в **stdout** через `log/slog` (уровни `Info` / `Error`). Смотреть:

```bash
docker compose logs -f bot
```

Полезные события: `referral created`, `Granted referral bonus`, `purchase processed`, ошибки платежей и Remnawave.

### Таблицы в файлах (CSV) — оплаты, рефералы, лента событий

Образ бота **не пишет** отдельный `.log` в папку проекта: всё идёт в Docker. Чтобы открыть **понятную таблицу в файле** (Excel / Numbers / LibreOffice), выгружай данные из Postgres бота:

```bash
cd apps/telegram-shop
bash scripts/export_audit_log.sh
```

Или из корня репозитория: `make bot-export-audit`.

Появятся файлы в **`apps/telegram-shop/logs/`**:

| Файл | Содержимое |
|------|------------|
| `latest_export_purchases.csv` | Все записи `purchase` + `buyer_telegram_id` |
| `latest_export_referrals.csv` | Рефералы: пригласивший / приглашённый / `bonus_granted` / число успешных оплат приглашённого |
| `latest_export_timeline.csv` | Объединённая лента: покупки + приглашения по реф-ссылке |
| `latest_docker_bot.log` | Последние ~5000 строк **сырого** лога контейнера `bot` |

Рядом сохраняются копии с меткой времени (`*_2026…csv`), чтобы не затирать историю. Папка `logs/*.csv` и `logs/docker_bot_*.log` в `.gitignore` — в git не коммитятся.

### SQL для админской статистики (Postgres бота)

Подключиться к БД контейнера (`POSTGRES_*` из `.env`):

```bash
docker compose exec db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

Сколько пригласил каждый и сколько из них уже «дошли до оплаты» (бонус выдан):

```sql
SELECT
  referrer_id,
  COUNT(*) AS invited,
  COUNT(*) FILTER (WHERE bonus_granted) AS paid_invited
FROM referral
GROUP BY referrer_id
ORDER BY invited DESC;
```

Детализация по одному пригласившему (подставь `123456789`):

```sql
SELECT r.referee_id, r.used_at, r.bonus_granted
FROM referral r
WHERE r.referrer_id = 123456789
ORDER BY r.used_at DESC;
```

В бесплатной версии **нет** отдельной админ-панели с графиками рефералов (это уже уровень платного RWP Shop или свой Grafana поверх логов/SQL).

## Ссылки

- Upstream-репозиторий: <https://github.com/Jolymmiels/remnawave-telegram-shop>
- Документация: <https://remnawave-telegram-shop-bot-doc.vercel.app/>
- Remnawave Panel: <https://docs.rw/>
