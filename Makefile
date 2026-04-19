PYTHON ?= python3
BOT_DIR := apps/telegram-shop
COMPOSE ?= docker compose

.PHONY: help bot-up bot-down bot-logs bot-pull bot-restart bot-ps secret-scan verify ci clean

help:
	@echo "VPN Product (Remnawave + готовый Telegram-shop бот) — Makefile"
	@echo
	@echo "  make bot-up         — поднять Telegram-бот (apps/telegram-shop, docker compose up -d)"
	@echo "  make bot-down       — остановить и удалить контейнеры бота"
	@echo "  make bot-logs       — tail логов бота"
	@echo "  make bot-pull       — docker compose pull + up -d (обновление образа)"
	@echo "  make bot-restart    — перезапуск бота без обновления"
	@echo "  make bot-ps         — статус контейнеров бота"
	@echo "  make secret-scan    — поиск утечек секретов в репо"
	@echo "  make verify         — всё, что гоняет CI (secret-scan + compose config)"

bot-up:
	@test -f $(BOT_DIR)/.env || (echo "Сначала скопируй: cp $(BOT_DIR)/.env.sample $(BOT_DIR)/.env и заполни значения" && exit 1)
	cd $(BOT_DIR) && $(COMPOSE) up -d

bot-down:
	cd $(BOT_DIR) && $(COMPOSE) down

bot-logs:
	cd $(BOT_DIR) && $(COMPOSE) logs -f --tail=200

bot-pull:
	@test -f $(BOT_DIR)/.env || (echo "Сначала скопируй: cp $(BOT_DIR)/.env.sample $(BOT_DIR)/.env и заполни значения" && exit 1)
	cd $(BOT_DIR) && $(COMPOSE) pull && $(COMPOSE) up -d

bot-restart:
	cd $(BOT_DIR) && $(COMPOSE) restart

bot-ps:
	cd $(BOT_DIR) && $(COMPOSE) ps

secret-scan:
	$(PYTHON) scripts/secret_scan.py

bot-compose-check:
	cd $(BOT_DIR) && $(COMPOSE) config >/dev/null

verify: secret-scan bot-compose-check

ci: verify

clean:
	@echo "nothing to clean (бот теперь — готовый docker-образ)"
