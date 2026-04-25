PYTHON ?= python3
BOT_DIR := apps/bedolaga-bot
XRAY_CHECKER_DIR := deploy/xray-checker
COMPOSE ?= docker compose

.PHONY: help bot-up bot-down bot-logs bot-pull bot-restart bot-ps bot-assets secret-scan verify ci clean

help:
	@echo "VPN Product (Remnawave + Bedolaga Telegram-бот) — Makefile"
	@echo
	@echo "  make bot-up         — поднять Bedolaga (apps/bedolaga-bot, docker compose up -d)"
	@echo "  make bot-down       — остановить и удалить контейнеры бота"
	@echo "  make bot-logs       — tail логов бота"
	@echo "  make bot-pull       — docker compose pull + up -d (обновление образа)"
	@echo "  make bot-restart    — перезапуск без обновления"
	@echo "  make bot-ps         — статус контейнеров"
	@echo "  make bot-assets     — скачать vpn_logo.png (не хранится в git)"
	@echo "  make secret-scan    — поиск утечек секретов в репо"
	@echo "  make verify         — secret-scan + docker compose config (бот + xray-checker + панель Remnawave, CI)"

bot-assets:
	cd $(BOT_DIR) && bash scripts/fetch_assets.sh

bot-up:
	@test -f $(BOT_DIR)/.env || (echo "Создай $(BOT_DIR)/.env — см. README: curl upstream .env.example" && exit 1)
	@test -f $(BOT_DIR)/vpn_logo.png || (cd $(BOT_DIR) && bash scripts/fetch_assets.sh)
	cd $(BOT_DIR) && $(COMPOSE) up -d

bot-down:
	cd $(BOT_DIR) && $(COMPOSE) down

bot-logs:
	cd $(BOT_DIR) && $(COMPOSE) logs -f --tail=200

bot-pull:
	@test -f $(BOT_DIR)/.env || (echo "Создай $(BOT_DIR)/.env — см. README" && exit 1)
	@test -f $(BOT_DIR)/vpn_logo.png || (cd $(BOT_DIR) && bash scripts/fetch_assets.sh)
	cd $(BOT_DIR) && $(COMPOSE) pull && $(COMPOSE) up -d

bot-restart:
	cd $(BOT_DIR) && $(COMPOSE) restart

bot-ps:
	cd $(BOT_DIR) && $(COMPOSE) ps

secret-scan:
	$(PYTHON) scripts/secret_scan.py

bot-compose-check:
	cd $(BOT_DIR) && $(COMPOSE) config >/dev/null

xray-checker-compose-check:
	cd $(XRAY_CHECKER_DIR) && cp -f .env.example .env && $(COMPOSE) config >/dev/null

# Панель Remnawave: только если нет локального .env (не затираем секреты разработчика)
remnawave-panel-compose-check:
	@if [ -f deploy/remnawave/panel/.env ]; then \
	  echo "[skip] deploy/remnawave/panel/.env уже есть — проверка compose пропущена"; \
	else \
	  cd deploy/remnawave/panel && cp -f .env.example .env && $(COMPOSE) config >/dev/null && rm -f .env; \
	fi

verify: secret-scan bot-compose-check xray-checker-compose-check remnawave-panel-compose-check

ci: verify

clean:
	@echo "nothing to clean (образы Docker кэшируются локально)"
