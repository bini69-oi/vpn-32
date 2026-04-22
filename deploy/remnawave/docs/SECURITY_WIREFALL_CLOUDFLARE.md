# Защита от DDoS и подбора пароля: Cloudflare + host firewall (Wirefall)

Схема из двух слоёв: **трафик к панели/подписке по доменам** — через **Cloudflare**; **лишние порты на сервере** — режет **фаервол на Linux (UFW)** в репозитории называем условно *Wirefall*.

Ни один скрипт не заменяет **сильные пароли / MFA / вход по SSH-ключу**. Цель — убрать обход Cloudflare на IP origin, сузить поверхность атаки и разгрузить сервер от мусора.

---

## 1. Cloudflare (панель и подписка по HTTPS)

### DDoS и нагрузка на L7

- Домены `PANEL_DOMAIN` и `SUB_DOMAIN` должны быть в режиме **Proxied (orange cloud)** — тогда фильтрация и анти-DDoS применяются на стороне Cloudflare, а не только на вашем VPS.
- В разделе **Security** включите по возможности **WAF**, **Bot Fight Mode** (или аналог по вашему плану CF).
- Для логина в панель: **Rate limiting** (правило на URI логина/API) — снижает брутфорс по HTTP без полной блокировки легитимных пользователей.
- Режим SSL: **Full (strict)** — между клиентом и CF шифрование, между CF и origin — тоже валидный сертификат (Caddy/Let’s Encrypt).

### Брутфорс именно веб-панели

- Скрипт **`remnawave-cloudflare-origin`** (см. основной README) — на origin в **80/443** попадает только трафик с IP-диапазонов Cloudflare; прямой заход по `https://IP-сервера` к панели отсекается.
- Дополнительно для админки: **Cloudflare Access** на `PANEL_DOMAIN` (Zero Trust) — отдельный слой перед формой логина Remnawave.

Подбор пароля по **SSH (порт 22)** Cloudflare не фильтрует — это не HTTP. См. раздел 3.

---

## 2. Wirefall: UFW на хосте

Скрипты (запуск **от root** на чистой Ubuntu/Debian с `ufw`):

| Сервер | Скрипт | Назначение |
|--------|--------|------------|
| Панель | `deploy/remnawave/scripts/harden_ufw_panel.sh` | Закрыть всё входящее по умолчанию; открыть SSH и 80/443 под Caddy |
| Нода | `deploy/remnawave/scripts/harden_ufw_node.sh` | То же; плюс `NODE_PORT` **только** с IP панели |

Перед включением:

1. Убедитесь, что **SSH стабилен** (ключи, доступ не потеряете).
2. На панели сначала поднимите Docker и Caddy, затем при необходимости включайте UFW (см. предупреждение в скрипте про Docker).

Порядок рекомендуется такой:

1. Поднять панель, выпустить сертификаты.
2. Включить **orange cloud** в Cloudflare.
3. Включить **`remnawave-cloudflare-origin`** (iptables allowlist для 80/443).
4. Запустить **`harden_ufw_panel.sh`** с ограничением SSH по своему IP, если возможно.

---

## 3. SSH: защита от подбора пароля

Cloudflare сюда **не относится** (это не тот протокол).

Рекомендации:

1. **Вход по ключу**, отключить пароли: в `/etc/ssh/sshd_config` — `PasswordAuthentication no`, `PermitRootLogin prohibit-password` (или `no`), затем `systemctl reload sshd`.
2. Ограничить **кто** может стучаться в 22: переменная `ADMIN_SSH_CIDR` в `harden_ufw_panel.sh` / `harden_ufw_node.sh` (например `203.0.113.10/32`).
3. По желанию: **Fail2ban** для `sshd` — пакет из дистрибутива, jail на неудачные попытки.

---

## 4. Нода и DDoS

Клиентский VPN-трафик в типичном Remnawave идёт на **NODE_PORT** с интернета (пользователи подключаются к ноде напрямую). **Cloudflare между клиентом и Xray здесь не стоит** — защита другая.

Скрипт **`harden_ufw_node.sh`** по умолчанию (`NODE_INBOUND=clients`) открывает **NODE_PORT для всех** — иначе VPN не заработает. Режим `NODE_INBOUND=panel-only` + `PANEL_IP` — только для нестандартных схем (может отключить доступ пользователей, если тот же порт нужен им).

Защита ноды от злоупотреблений:

- Лимиты и политики в **Remnawave Panel** (пользователи, HWID, тарифы).
- Объёмный **L3/L4 DDoS на IP ноды** обычно гасит **хостинг / upstream**; на VPS без анти-DDoS сети «закрыть полностью» volumetric-атаку скриптами на сервере нельзя — нужен провайдер с фильтрацией или отдельный scrubbing.

---

## Ссылки

- Cloudflare IP ranges: `https://www.cloudflare.com/ips/`
- Скрипт origin lockdown: `deploy/remnawave/scripts/lockdown_cloudflare_origin.sh`
- Docker и фаервол: `https://docs.docker.com/network/packet-filtering-firewalls/`
