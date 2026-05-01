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
  - **NODE_PORT** доступен с интернета для **клиентского VPN**; SSH и прочие порты — по политике фаервола (см. [`docs/SECURITY_WIREFALL_CLOUDFLARE.md`](docs/SECURITY_WIREFALL_CLOUDFLARE.md))

Официальная дока:  
- Panel: `https://docs.rw/docs/install/remnawave-panel/`  
- Node: `https://docs.rw/docs/install/remnawave-node/`

---

## Порядок установки

1) Сначала **Panel**  
2) Потом **Node**

Полная пошаговая цепочка (команды на серверах + что ввести в UI + нода) — в разделе **[Пошагово: панель, UI и нода](#remnawave-quickstart-full)** ниже.

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

<a id="remnawave-quickstart-full"></a>

## Пошагово: поднять панель → что ввести в UI → поднять ноду

Ниже один сквозной сценарий: **сначала панель** (сервер + браузер + токен в `.env`), **потом нода** (создание ноды в UI + сервер ноды). Имена доменов замените на свои (`panel.example.com`, `sub.example.com`).

### 1) Сервер панели — установка (под `root`)

```bash
apt-get update -qq && apt-get install -y git ca-certificates curl openssl
git clone <URL_ВАШЕГО_РЕПОЗИТОРИЯ> /root/vpn-32 && cd /root/vpn-32

# Рекомендуемый вариант: скрипт сам пропишет домены, JWT и шаблон Caddy, поднимет контейнеры
sudo bash deploy/remnawave/scripts/install_panel.sh panel.example.com sub.example.com
```

Что делает скрипт с **двумя аргументами**:

- ставит Docker (если ещё нет);
- копирует `docker-compose.yml`, `.env`, `Caddyfile` в `/opt/remnawave`;
- подставляет в `.env`: `PANEL_DOMAIN`, `FRONT_END_DOMAIN`, `SUB_PUBLIC_DOMAIN`, случайные `JWT_*`;
- записывает **временный** `REMNAWAVE_API_TOKEN` (случайная строка) — его нужно **заменить** на токен из UI (шаг 3);
- выполняет `docker compose up -d` в `/opt/remnawave`;
- ставит таймер бэкапа.

Если Caddy уже был установлен ранее и вы **обновили** `Caddyfile` в репозитории, перезапишите файл на сервере и перезапустите Caddy:

```bash
sudo cp /root/vpn-32/deploy/remnawave/panel/caddy/Caddyfile /opt/remnawave/caddy/Caddyfile
cd /opt/remnawave && docker compose restart caddy
```

Проверка, что контейнеры живы:

```bash
cd /opt/remnawave && docker compose ps
```

Первый запуск SSL: пока DNS A/AAAA для обоих имён не указывают на этот сервер, Caddy не выпустит сертификаты — смотрите логи: `docker compose logs -f caddy`.

**Без двух аргументов** скрипт только положит файлы; тогда вручную заполните `/opt/remnawave/.env` и `caddy/Caddyfile` (см. раздел [Panel установка](#panel-install-advanced) ниже) и выполните `cd /opt/remnawave && docker compose up -d`.

---

### 2) Браузер — первый вход и роль super-admin

1. Откройте в браузере **`https://panel.example.com`** (ваш `PANEL_DOMAIN`).
2. На экране **регистрации первого пользователя** введите:
   - **email** (логин);
   - **пароль** (сохраните — восстановление через почту в стеке может быть недоступно; при потере доступа см. [Rescue CLI](#rescue-cli-superadmin) ниже).
3. Отправьте форму. **Первый зарегистрированный пользователь в инсталляции становится super-admin** — дальнейшие пользователи не получают эту роль автоматически.

Интерфейс Remnawave со временем обновляется; если пункты меню называются чуть иначе, ориентируйтесь на разделы **Settings**, **Management** и официальную [quick start](https://docs.rw/docs/learn-en/quick-start).

---

### 3) Браузер — API-токен для страницы подписок + правка `.env` на панели

Страница подписок (`https://sub.example.com`) ходит в API панели с токеном из переменной **`REMNAWAVE_API_TOKEN`** в `/opt/remnawave/.env`. Пока там случайная заглушка от скрипта, подписка может отдавать **502**.

1. В панели откройте **Settings** → **API Tokens** (или аналог «API / токены»).
2. Нажмите создание нового токена, задайте имя (например `subscription-page`), при необходимости отметьте права по документации Remnawave.
3. **Скопируйте выданный токен** (часто показывается один раз).

На сервере панели:

```bash
sudoedit /opt/remnawave/.env
# Найдите строку REMNAWAVE_API_TOKEN=... и вставьте токен из UI целиком, без пробелов и кавычек лишних
cd /opt/remnawave && docker compose up -d
```

Проверка:

```bash
curl -sI "https://panel.example.com/" | head -5
curl -sI "https://sub.example.com/" | head -5
```

Ожидаются ответы **не** 502 от `sub` (конкретный код зависит от маршрута; главное — сервис отвечает).

---

### 4) Браузер — создать ноду и получить `SECRET_KEY`

Сделайте это **до** или **после** подготовки сервера ноды, но **секрет и порт** понадобятся в `/opt/remnanode/.env`.

1. Зайдите в **Management** → **Nodes** → кнопка добавления ноды (**+** / **Add**).
2. Заполните поля (названия в UI могут слегка отличаться):
   - **Имя ноды** — любое понятное вам (например `nl-1`).
   - **Адрес / IP / Host** — **публичный IPv4 (или IPv6) сервера ноды**, тот же, по которому клиенты будут стучаться в VPN. Не указывайте внутренние адреса вида `192.168.x.x` и не подставляйте домен панели или `sub` — нода обычно на **отдельном** VPS.
   - **Node Port** — TCP-порт ноды (например `2222`). Он должен **совпасть** с `NODE_PORT` в `/opt/remnanode/.env` на сервере ноды и быть **открыт** на фаерволе облака/хоста для клиентского VPN.
3. Сохраните ноду. В карточке ноды или в мастере создания скопируйте **`SECRET_KEY`** (секрет ноды) — длинная строка; без неё нода не авторизуется на панели.

Если позже смените порт или секрет в UI — обновите `.env` на ноде и перезапустите `docker compose`.

---

### 5) Сервер ноды — установка и запуск (под `root`)

Подставьте свой репозиторий, порт и секрет из шага 4.

```bash
apt-get update -qq && apt-get install -y git ca-certificates curl
git clone <URL_ВАШЕГО_РЕПОЗИТОРИЯ> /root/vpn-32 && cd /root/vpn-32
sudo bash deploy/remnawave/scripts/install_node.sh
```

Отредактируйте `/opt/remnanode/.env`:

- **`NODE_PORT`** — тот же, что **Node Port** в UI (например `2222`);
- **`SECRET_KEY`** — в кавычках, значение из UI, **без** пробелов и переносов.

Пример (замените значения):

```bash
sudo tee /opt/remnanode/.env >/dev/null <<'EOF'
NODE_PORT=2222
SECRET_KEY="ВСТАВЬТЕ_СЕКРЕТ_ИЗ_UI"
EOF
sudo chmod 0600 /opt/remnanode/.env
cd /opt/remnanode && docker compose up -d
docker compose logs --tail=50
```

На стороне облачного провайдера откройте **входящий TCP (и при необходимости UDP)** для **`NODE_PORT`**. Дополнительно для инбаундов из профиля (другие порты) — по вашему профилю в панели. На Linux-хосте при желании включите UFW-скрипт из репозитория (см. [Node установка](#node-install-advanced) ниже и [`docs/SECURITY_WIREFALL_CLOUDFLARE.md`](docs/SECURITY_WIREFALL_CLOUDFLARE.md)).

В панели нода должна перейти в состояние **онлайн / connected** (формулировка зависит от версии). Если нет — смотрите логи контейнера ноды и проверку `SECRET_KEY`, порта и фаервола.

---

### 6) Пользователь и подписка (кратко)

Дальше в UI создаются **пользователи**, **хосты** (привязка ноды и профиля Xray), выдаётся **subscription URL**. Публичный домен в ссылках клиентов — тот, что в **`SUB_PUBLIC_DOMAIN`** (у вас в шаблоне это `sub.*`). Точные шаги зависят от версии Remnawave; см. [официальную документацию](https://docs.rw/).

---

<a id="panel-install-advanced"></a>

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

- `remnawave`, `remnawave-subscription-page`, Postgres и Redis **не** публикуют порты на хост — только внутри сети Docker; наружу **только Caddy** на `80/tcp` и `443/tcp`.
- Метрики (`/metrics`) доступны изнутри контейнера `remnawave` по healthcheck; с хоста без проброса — при необходимости `docker exec`.
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

### 3.2) DDoS и брутфорс по HTTPS (настройки в Cloudflare)

Cloudflare **не закрывает SSH** и не заменяет сильный пароль/MFA в самой панели, но снимает основную волну L7 и часть L3/L4 для **проксируемых доменов** (orange cloud).

В дашборде Cloudflare имеет смысл включить **WAF**, **Bot Fight** (или аналог по тарифу), **Rate limiting** на пути логина/API панели. Подробнее и про ограничения — **[`docs/SECURITY_WIREFALL_CLOUDFLARE.md`](docs/SECURITY_WIREFALL_CLOUDFLARE.md)**.

### 3.3) Wirefall: фаервол на хосте панели (UFW)

После того как у вас стабильно работают SSH, Docker и Caddy, можно включить **default deny** на входящие и явно открыть только нужные порты:

```bash
cd <repo>
# лучше сузить SSH до своего IP:
sudo CONFIRM=1 ADMIN_SSH_CIDR=ВАШ_IP/32 bash deploy/remnawave/scripts/harden_ufw_panel.sh
```

Без `ADMIN_SSH_CIDR` скрипт разрешит SSH с любого адреса (удобно, но слабее против брутфорса по SSH — тогда обязательно **ключи** и отключение пароля в `sshd`). Полная схема: тот же файл **`docs/SECURITY_WIREFALL_CLOUDFLARE.md`**.

<a id="rescue-cli-superadmin"></a>

### 4) Первый запуск: создать superadmin

По доке Remnawave: **первый зарегистрированный пользователь становится super-admin**.  
Ссылка: `https://docs.rw/docs/learn-en/quick-start` (секция Initial Setup / super-admin)

Если потеряли доступ — есть Rescue CLI:

```bash
docker exec -it remnawave remnawave
```

Источник: `https://docs.rw/docs/learn-en/quick-start`

---

<a id="node-install-advanced"></a>

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

Важно: **клиенты VPN** должны достучаться до **NODE_PORT** по сети (обычно порт открыт на весь интернет). Панель управляет нодой по тому же или связанному каналу — см. официальную доку. От **лишних** портов на сервере ноды защищает фаервол (Wirefall):

```bash
cd <repo>
sudo CONFIRM=1 NODE_PORT=2222 bash deploy/remnawave/scripts/harden_ufw_node.sh
# опционально сузить SSH:
# sudo CONFIRM=1 NODE_PORT=2222 ADMIN_SSH_CIDR=ВАШ_IP/32 bash deploy/remnawave/scripts/harden_ufw_node.sh
```

Источник: `https://docs.rw/docs/install/remnawave-node/`  
Схема безопасности: [`docs/SECURITY_WIREFALL_CLOUDFLARE.md`](docs/SECURITY_WIREFALL_CLOUDFLARE.md)

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
   - Проверьте firewall: для **клиентов** `NODE_PORT` должен быть **доступен с интернета** (если не используете нестандартную схему); для **панели** — см. логи ноды и сеть между панелью и нодой.
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
