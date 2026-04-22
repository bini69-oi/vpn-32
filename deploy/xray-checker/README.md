# Xray Checker

Мониторинг доступности прокси (VLESS, VMess, Trojan, Shadowsocks), метрики для Prometheus, веб-интерфейс на порту **2112**.

- **Исходный код и релизы:** [github.com/kutovoys/xray-checker](https://github.com/kutovoys/xray-checker)
- **Документация:** [xray-checker.kutovoy.dev](https://xray-checker.kutovoy.dev/)
- В экосистеме Remnawave: [Awesome Remnawave — Xray Checker](https://docs.rw/docs/awesome-remnawave/#xray-checker)

## Запуск

Рядом с панелью или на отдельном сервере с доступом к URL подписки:

```bash
cd deploy/xray-checker
cp .env.example .env
# отредактируйте SUBSCRIPTION_URL — ссылка подписки из Remnawave
docker compose up -d
```

UI и метрики слушают только **127.0.0.1:2112** на хосте. Снаружи открывать не обязательно; при необходимости — reverse proxy или SSH-туннель.

```bash
docker compose logs -f xray-checker
```

Остановка: `docker compose down`.
