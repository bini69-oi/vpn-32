# Приложения (`apps/`)

Клиентские сервисы вокруг Remnawave Panel.

| Каталог | Назначение |
|---------|------------|
| [`bedolaga-bot/`](bedolaga-bot/README.md) | **[Bedolaga](https://github.com/BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot)** — продажи VPN через Telegram (+ Web API, Postgres, Redis). Образ `ghcr.io/bedolaga-dev/remnawave-bedolaga-telegram-bot:latest`; в репозитории — усиленный compose (API только на `127.0.0.1`, БД не наружу). |

Запуск: см. [`bedolaga-bot/README.md`](bedolaga-bot/README.md). Из корня: `make bot-up`, `make bot-logs`, `make bot-pull`, `make bot-assets`.

## Архив

- [`archive/telegram-shop-jolymmiels/`](../archive/telegram-shop-jolymmiels/) — прежний Docker-бот [Jolymmiels/remnawave-telegram-shop](https://github.com/Jolymmiels/remnawave-telegram-shop).
- [`archive/vpn-telegram-bot-custom/`](../archive/vpn-telegram-bot-custom/) — собственный Python-бот на aiogram 3.
- [`archive/telegram-miniapp/`](../archive/telegram-miniapp/) — Mini App под старый `vpn-productd`.
- [`archive/telegram-bot-legacy/`](../archive/telegram-bot-legacy/) — самая ранняя версия бота.
