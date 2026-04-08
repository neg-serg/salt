# Xray VPN — использование из CLI

## Обзор

Xray используется как CLI VPN-клиент со стеком протоколов VLESS + Reality + XHTTP. Конфигурация извлечена из AmneziaVPN и может использоваться независимо через бинарник `xray`, идущий в составе `v2rayn-bin`.

## Архитектура

```
Приложение → tun2 (tun2socks) → SOCKS5 127.0.0.1:10808 → Xray → VPN-сервер → Интернет
```

Два независимых компонента:

1. **Xray** — VLESS-прокси-клиент, выставляет SOCKS5 на `127.0.0.1:10808`
2. **tun2socks** — создаёт TUN-интерфейс и маршрутизирует весь системный трафик через SOCKS5-прокси (опционально, нужен только для системного VPN)

## Зависимости

- `v2rayn-bin` (AUR) — содержит `/opt/v2rayn-bin/bin/xray/xray`
- Симлинк: `~/.local/bin/xray` → `/opt/v2rayn-bin/bin/xray/xray`

## Конфигурация

Файл конфига: `~/.config/xray/config.json`

Стек протоколов:

| Уровень | Значение |
|---------|----------|
| Протокол | VLESS |
| Транспорт | XHTTP |
| Безопасность | Reality (TLS fingerprint: random) |
| SNI | `www.google.com` |
| Сервер | `204.152.223.171:8443` |
| Локальный SOCKS5 | `127.0.0.1:10808` |

## Использование

### Режим 1: только SOCKS5-прокси (рекомендуется)

Запуск Xray как локального SOCKS5-прокси без изменения системной маршрутизации:

```bash
xray run -c ~/.config/xray/config.json
```

Использование из приложений:

```bash
# curl
curl -x socks5h://127.0.0.1:10808 https://ifconfig.me

# Переменная окружения (работает со многими CLI-инструментами)
export ALL_PROXY=socks5h://127.0.0.1:10808

# Браузер — установить SOCKS5-прокси 127.0.0.1:10808 в настройках сети
```

### Режим 2: системный VPN (через tun2socks)

Маршрутизация всего системного трафика через VPN, аналогично AmneziaVPN:

```bash
# 1. Запустить xray
xray run -c ~/.config/xray/config.json &

# 2. Создать TUN-интерфейс
sudo ip tuntap add mode tun dev tun2
sudo ip addr add 10.33.0.2/24 dev tun2
sudo ip link set tun2 up

# 3. Добавить маршрут к VPN-серверу через реальный шлюз (предотвращение петли)
sudo ip route add 204.152.223.171/32 via 192.168.2.1 dev eno1

# 4. Установить default route через TUN
sudo ip route add default via 10.33.0.1 dev tun2 metric 50

# 5. Запустить tun2socks
/opt/AmneziaVPN/client/bin/tun2socks -device tun://tun2 -proxy socks5://127.0.0.1:10808
```

Для отключения:

```bash
sudo ip route del default via 10.33.0.1 dev tun2
sudo ip route del 204.152.223.171/32 via 192.168.2.1
sudo ip link del tun2
# Завершить процессы xray и tun2socks
```

### Режим 3: проксирование отдельных приложений (proxychains)

```bash
proxychains -q firefox
```

Требуется `proxychains-ng` с настройкой SOCKS5 `127.0.0.1 10808` в `/etc/proxychains.conf`.

## Диагностика

```bash
# Проверить, запущен ли xray
pgrep -a xray

# Проверить SOCKS5-порт
ss -tlnp | grep 10808

# Проверить внешний IP через прокси
curl -x socks5h://127.0.0.1:10808 https://ifconfig.me

# Проверить внешний IP напрямую
curl https://ifconfig.me

# Проверить текущий default route
ip route show default
```

## Связь с AmneziaVPN

AmneziaVPN хранит тот же конфиг Xray внутри `~/.config/AmneziaVPN.ORG/AmneziaVPN.conf` (формат Qt settings, JSON внутри `@ByteArray`). Автономный конфиг `~/.config/xray/config.json` — это чистое извлечение из встроенного конфига.

При изменении конфига AmneziaVPN (новый сервер, новые ключи) нужно заново извлечь JSON из `last_config` в `AmneziaVPN.conf` и обновить `~/.config/xray/config.json`.

## Заметки

- Протокол Reality маскирует соединение под обычный HTTPS-трафик к `www.google.com` — эффективен против DPI-блокировок.
- Режим SOCKS5-прокси не влияет на системный DNS. Используйте `socks5h://` (с `h`), чтобы DNS-запросы тоже шли через прокси.
- Описание VPN-сервера в AmneziaVPN — "LA-VPN-lev-ra" (Лос-Анджелес).
