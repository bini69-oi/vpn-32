# Архив

Здесь лежит код, снятый с эксплуатации, но сохранённый для истории и forensics.
В активном пайплайне (CI, деплой, бот) ничего из `archive/` не используется.

| Каталог | Что было |
|---------|----------|
| `vpn-productd/` | Полный legacy-стек: Go-сервис `vpn-productd` + `vpn-productctl` (`cmd/`, `internal/`), его systemd-юниты, deploy-скрипты, мониторинг (Grafana/Prometheus), logrotate, Caddy-пример, env-файлы. Использовал 3x-ui как back-of-house. **Заменён на Remnawave Panel + Node.** |
| `vpn-telegram-bot-custom/` | Собственный Telegram-бот на aiogram 3 (Python 3.12/3.13) с 205 тестами, `ruff`/`mypy`/`pytest-cov` в CI. Заменён на готовый [`apps/telegram-shop/`](../apps/telegram-shop/README.md) (upstream-бот `Jolymmiels/remnawave-telegram-shop`). |
| `telegram-miniapp/` | Mini App на Node (Express) — ходил только в `vpn-productd`. На Remnawave не переписан. |
| `telegram-bot-legacy/` | Самая ранняя версия бота на `python-telegram-bot` (до aiogram 3-перепиcа). |
| `tests-integration-coverage/` | Старые bash-скрипты `coverall`/`coverall2` из апстримного Xray-форка. |
| `config-examples/` | `secure_profile.json` из `internal/examples/` — никем не использовался. |

## Если нужно вернуть

```bash
# вернуть кастомный aiogram-бот в активный пайплайн
git mv archive/vpn-telegram-bot-custom apps/vpn-telegram-bot
# и восстановить bot-quality-job в .github/workflows/ci.yml + Python-таргеты в Makefile
# из истории до коммита перехода на remnawave-telegram-shop

# вернуть legacy-бота в корень
git mv archive/telegram-bot-legacy telegram-bot

# вернуть vpn-productd (потребуется восстановить go.mod / Makefile-цели)
git mv archive/vpn-productd/cmd cmd
git mv archive/vpn-productd/internal internal
git restore --source=<commit-where-go.mod-existed> go.mod go.sum .golangci.yml Dockerfile Makefile
```

## Что было удалено

Полностью удалены (не перенесены в `archive/`) исходники самого Xray-core форка
(`app/`, `common/`, `core/`, `features/`, `infra/`, `main/`, `proxy/`, `transport/`,
`benchmarks/`, `configs/`, `tests/integration/`) — Remnawave использует апстримный
upstream-Xray внутри своего Node-контейнера, держать форк отдельно нет смысла.
История доступна в git до коммита перехода.
