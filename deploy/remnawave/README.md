## Remnawave deploy (stage 1)

Этот каталог готовит деплой **Remnawave Panel** и **Remnawave Node** (2 сервера: panel и node).  
Старых пользователей не переносим (тестовый сервер). Telegram-бот и оплата — следующие этапы.

### Требования к серверам

- **Panel server**
  - минимум **1 vCPU, 1GB RAM**
  - публичный IP
  - Docker
  - DNS для `PANEL_DOMAIN` и `SUB_DOMAIN` указывает на IP панели
- **Node server**
  - минимум **1 vCPU, 1GB RAM** (важнее сеть и стабильность)
  - публичный IP
  - Docker
  - **открыт NODE_PORT только для IP панели** (firewall)

Официальная дока:  
- Panel: `https://docs.rw/docs/install/remnawave-panel/`  
- Node: `https://docs.rw/docs/install/remnawave-node/`

---

## Порядок установки

1) Сначала **Panel**  
2) Потом **Node**

---

## DNS (обязательно до SSL)

Сделайте A-записи:

- `PANEL_DOMAIN` → IP панели
- `SUB_DOMAIN` → IP панели

Почему: Caddy автоматически выпустит SSL, но только если домены резолвятся на панель.

Если используете **Cloudflare**, после первичной проверки доменов включите для обоих хостов
`PANEL_DOMAIN` и `SUB_DOMAIN` режим **Proxy / orange cloud**. Иначе origin-IP панели будет
обходить защиту Cloudflare напрямую.

---

## Panel установка

### 1) Подготовить файлы

На сервере панели:

```bash
git clone <YOUR_REPO_URL>
cd <repo>
sudo bash deploy/remnawave/scripts/install_panel.sh
```

Скрипт:
- ставит Docker (официальный install script)
- кладёт `docker-compose.yml`, `.env` и `Caddyfile` в `/opt/remnawave`
- запускает `docker compose up -d`
- ставит systemd таймер бэкапа (00:00 UTC, retention 14 дней)

### 2) Настроить `/opt/remnawave/.env`

Минимально замените плейсхолдеры:

- `PANEL_DOMAIN=...`
- `FRONT_END_DOMAIN=...` (обычно = домен панели)
- `SUB_PUBLIC_DOMAIN=...` (в этой миграции = `SUB_DOMAIN`)
- `JWT_AUTH_SECRET=""`
- `JWT_API_TOKENS_SECRET=""`

⚠️ ВАЖНО: **панель НЕ ЗАПУСТИТСЯ**, если `SUB_PUBLIC_DOMAIN` не задан реальным доменом.  
Указывайте домен **без** `https://` и **без** слеша в конце. Пример: `sub.example.com`

Генерация JWT секретов (как требуется в задаче):

```bash
openssl rand -hex 32
```

 (даёт hex-строку длиной 64 символа = 256 бит энтропии)

Официальная дока: `https://docs.rw/docs/install/remnawave-panel/`

### 3) Reverse proxy и SSL (Caddy)

Используйте `deploy/remnawave/panel/Caddyfile` как основу:

- `https://PANEL_DOMAIN` → `http://remnawave:3000`
- `https://SUB_DOMAIN` → `http://remnawave-subscription-page:3010`

Важно:

- В compose панель, метрики и subscription-page уже слушают только на `127.0.0.1`.
- Наружу остаются только `80/tcp` и `443/tcp` через Caddy.
- `443/udp` для origin отключён: HTTP/3 нужен клиенту до Cloudflare, а не до origin.
- Caddy прокидывает реальный IP пользователя из `CF-Connecting-IP`, когда трафик идёт через Cloudflare.

Официальный пример (subscription page, Caddy):  
`https://docs.rw/docs/install/subscription-page/bundled`

### 3.1) Закрыть origin от обхода Cloudflare

После того как в Cloudflare для `PANEL_DOMAIN` и `SUB_DOMAIN` включён **orange cloud**, включите
локальный firewall-allowlist для origin:

```bash
sudo systemctl enable --now remnawave-cloudflare-origin.service
sudo systemctl enable --now remnawave-cloudflare-origin.timer
```

Что делает защита:

- забирает актуальные IP-диапазоны Cloudflare с `https://www.cloudflare.com/ips-v4` и `https://www.cloudflare.com/ips-v6`
- разрешает доступ к `80/tcp` и `443/tcp` только от Cloudflare
- дропает прямые подключения к origin по IP, чтобы нельзя было обходить Cloudflare и брутфорсить панель в лоб
- обновляет allowlist по таймеру, чтобы не сломаться при изменении IP-диапазонов Cloudflare

Проверка:

```bash
sudo systemctl status remnawave-cloudflare-origin.service --no-pager
sudo systemctl status remnawave-cloudflare-origin.timer --no-pager
sudo iptables -S REMNAWAVE_CLOUDFLARE_ORIGIN
sudo ip6tables -S REMNAWAVE_CLOUDFLARE_ORIGIN
```

Если нужна максимальная защита админки от подбора пароля, поверх этого включите
**Cloudflare Access** именно на `PANEL_DOMAIN`, а `SUB_DOMAIN` оставьте публичным только для клиентских
подписок.

### 4) Первый запуск: создать superadmin

По доке Remnawave: **первый зарегистрированный пользователь становится super-admin**.  
Ссылка: `https://docs.rw/docs/learn-en/quick-start` (секция Initial Setup / super-admin)

Если потеряли доступ — есть Rescue CLI:

```bash
docker exec -it remnawave remnawave
```

Источник: `https://docs.rw/docs/learn-en/quick-start`

---

## Node установка

### 1) Добавить ноду в UI панели и получить SECRET_KEY

В панели:
- `Management` → `Nodes` → `+` (добавить ноду)
- обратите внимание на `Node Port` (должен совпасть с `NODE_PORT` на ноде)
- скопируйте `SECRET_KEY` (используется нодой)

Официальная дока: `https://docs.rw/docs/install/remnawave-node/`

### 2) Запустить ноду

На сервере ноды:

```bash
git clone <YOUR_REPO_URL>
cd <repo>
sudo bash deploy/remnawave/scripts/install_node.sh
```

Отредактируйте `/opt/remnanode/.env`:
- `NODE_PORT=2222` (или ваш)
- `SECRET_KEY="..."` (из UI)

Важно: закройте `NODE_PORT` во внешнем мире, откройте только для IP панели.  
Источник: `https://docs.rw/docs/install/remnawave-node/` (Important note)

---

## Проверка что всё работает

1) Убедиться что panel доступен по HTTPS:

```bash
curl -I "https://PANEL_DOMAIN"
```

2) Проверить subscription URL (в ответах Remnawave используется `SUB_PUBLIC_DOMAIN`):

```bash
curl -I "https://SUB_DOMAIN"
```

CHECK: точный формат subscription URL зависит от настроек Remnawave и профиля подписки в UI.  
Сверить: `https://docs.rw/docs/install/environment-variables#domains` и разделы про Subscription в UI.

---

## Бэкапы (panel)

Ставится через `install_panel.sh`:

- systemd timer: `vpn-backup.timer` (ежедневно 00:00 UTC)
- service: `vpn-backup.service`
- скрипт: `/usr/local/bin/remnawave-backup.sh`
- каталог: `/var/backups/remnawave`
- retention: 14 дней

Команды:

```bash
systemctl status vpn-backup.timer --no-pager
systemctl status vpn-backup.service --no-pager
ls -lah /var/backups/remnawave
```

---

## Troubleshooting (топ‑3)

1) **Node не подключается**
   - Проверьте firewall: `NODE_PORT` должен быть доступен **только** с IP панели.
   - Проверьте что `SECRET_KEY` точно совпадает с тем, что выдали в UI.
   - Источник: `https://docs.rw/docs/install/remnawave-node/`

2) **DNS / домены**
   - `PANEL_DOMAIN` и `SUB_DOMAIN` должны резолвиться на IP панели (A-записи).
   - До правильного DNS Caddy не выпустит сертификаты.

3) **SSL не выпускается (Caddy)**
   - Убедитесь что порты 80/443 доступны с интернета до панели (и не заняты другим сервисом).
   - Проверьте логи Caddy.
   - Источник (пример Caddy для subpage): `https://docs.rw/docs/install/subscription-page/bundled`

4) **После включения Cloudflare origin lock-down панель недоступна**
   - Проверьте, что у `PANEL_DOMAIN` и `SUB_DOMAIN` включён orange cloud, а не `DNS only`.
   - Если применили правила слишком рано, зайдите на сервер по SSH/консоли и временно выключите сервис:
     `sudo systemctl disable --now remnawave-cloudflare-origin.timer remnawave-cloudflare-origin.service`
