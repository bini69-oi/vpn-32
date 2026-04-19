# Приложения (`apps/`)

Клиентские сервисы вокруг Remnawave Panel.

| Каталог | Назначение |
|---------|------------|
| [`telegram-shop/`](telegram-shop/README.md) | Готовый Telegram-бот [Jolymmiels/remnawave-telegram-shop](https://github.com/Jolymmiels/remnawave-telegram-shop): продажа подписок, YooKassa / CryptoPay / Stars / Tribute, триал, рефералы. Поднимается одним `docker compose up -d`. |

Запуск и переменные окружения — в README подпроекта. Из корня репозитория удобно использовать `make bot-up` / `make bot-logs` / `make bot-pull`.

## Архив

- [`archive/vpn-telegram-bot-custom/`](../archive/vpn-telegram-bot-custom/) — собственный Python-бот на aiogram 3 (переведён в архив в пользу готового `telegram-shop`).
- [`archive/telegram-miniapp/`](../archive/telegram-miniapp/) — Mini App под старый `vpn-productd`.
- [`archive/telegram-bot-legacy/`](../archive/telegram-bot-legacy/) — самая первая версия бота.
