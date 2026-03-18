# Настройка Tailscale VPN

Tailscale — mesh VPN на базе WireGuard, создающий приватную сеть (tailnet) между всеми вашими устройствами. Это руководство охватывает установку, аутентификацию, подключение устройств и типовые операции.

## Предварительные требования

- Рабочая станция CachyOS с настроенным Salt
- Аккаунт Tailscale — создайте на [login.tailscale.com](https://login.tailscale.com) (бесплатный тариф поддерживает до 100 устройств)
- `network.tailscale: true` включён в `states/data/hosts.yaml` для вашего хоста

## Установка

Tailscale устанавливается автоматически через Salt:

```bash
just apply
```

Выполняются три действия:
1. Установка пакета `tailscale` (CLI + демон)
2. Включение и запуск службы `tailscaled`
3. Развёртывание stub-зоны Unbound для MagicDNS (`*.ts.net` → `100.100.100.100`)

Проверка:

```bash
tailscale --version
systemctl is-enabled tailscaled    # → enabled
systemctl is-active tailscaled     # → active
```

## Первая аутентификация

Аутентификация интерактивная (одноразовая, через браузер):

```bash
sudo tailscale up --accept-dns=false
```

Флаг `--accept-dns=false` **обязателен** — он предотвращает перехват DNS существующим стеком (Unbound + AdGuardHome).

Команда выведет URL:

```
To authenticate, visit:
    https://login.tailscale.com/a/xxxxxxxxxxxx
```

Откройте URL в браузере, войдите в аккаунт Tailscale и авторизуйте устройство.

Проверка подключения:

```bash
tailscale status
tailscale ip -4        # показывает ваш адрес 100.x.y.z
```

## Конфигурация DNS

### Как это работает

Рабочая станция использует собственный DNS-стек:
- **AdGuardHome** (127.0.0.1:53) — фильтрация рекламы, перенаправление в Unbound
- **Unbound** (127.0.0.1:5353) — рекурсивный резолвер с DNSSEC + DNS-over-TLS

Флаг `--accept-dns=false` гарантирует, что Tailscale НЕ изменяет системный резолвер. Вместо этого stub-зона в Unbound перенаправляет запросы `*.ts.net` на встроенный MagicDNS-резолвер Tailscale по адресу `100.100.100.100`.

### Проверка DNS

```bash
# Имена tailnet должны резолвиться через MagicDNS
dig <ваше-устройство>.ts.net

# Остальные домены — через существующий стек (без изменений)
dig example.com

# Проверить, что Unbound загрузил stub-зону
unbound-control list_stubs | grep ts.net
```

## Добавление устройств

### Linux (Arch/CachyOS/Manjaro)

```bash
sudo pacman -S tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up
```

### Linux (Debian/Ubuntu)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### Linux (Fedora)

```bash
sudo dnf install tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up
```

### Android

1. Установите **Tailscale** из Google Play Store
2. Откройте приложение, нажмите **Sign in**
3. Авторизуйтесь в аккаунте Tailscale
4. Устройство автоматически появится в tailnet

### iOS / macOS

1. Установите **Tailscale** из App Store
2. Откройте приложение, нажмите **Sign in** (iOS) или кликните иконку в меню-баре (macOS)
3. Авторизуйтесь в аккаунте Tailscale
4. На macOS: может потребоваться одобрить VPN-конфигурацию в Системных настройках

### Windows

1. Скачайте установщик с [tailscale.com/download/windows](https://tailscale.com/download/windows)
2. Запустите MSI-установщик
3. Кликните иконку Tailscale в системном трее → **Log in**
4. Авторизуйтесь в браузере

### Проверка нового устройства

С любого устройства, уже подключённого к tailnet:

```bash
tailscale status                    # список всех устройств
tailscale ping <имя-устройства>     # проверка связи
```

## Предоставление доступа внешним пользователям

Чтобы дать кому-то доступ к вашему tailnet:

1. Перейдите на [login.tailscale.com/admin/settings/sharing](https://login.tailscale.com/admin/settings/sharing)
2. В разделе **Share your network** нажмите **Generate invite link** или добавьте пользователя по email
3. Приглашённый регистрируется со своим аккаунтом Tailscale
4. По умолчанию общие пользователи видят все устройства — используйте ACL для ограничения

### Контроль доступа (ACL)

ACL управляются в консоли Tailscale: [login.tailscale.com/admin/acls](https://login.tailscale.com/admin/acls).

Пример: разрешить внешнему пользователю только SSH-доступ к рабочей станции:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["shared-user@example.com"],
      "dst": ["telfir:22"]
    }
  ]
}
```

## Типовые операции

### SSH через Tailscale

Проброс портов не нужен — используйте имя устройства в tailnet:

```bash
ssh user@<имя-устройства>
# или по Tailscale IP
ssh user@100.x.y.z
```

### Передача файлов

Отправить файл на другое устройство:

```bash
tailscale file cp myfile.txt <имя-устройства>:
```

Получить файлы на другом устройстве:

```bash
tailscale file get ~/dw/
```

### Exit Node

Использовать другое устройство как выходной узел (весь интернет-трафик через него):

На устройстве-выходном узле:

```bash
sudo tailscale set --advertise-exit-node
```

Затем одобрите exit node в админ-консоли.

На клиентском устройстве:

```bash
sudo tailscale set --exit-node=<имя-exit-node>
```

Отключить exit node:

```bash
sudo tailscale set --exit-node=
```

### Маршрутизация подсетей

Чтобы предоставить доступ к локальной сети через tailnet (например, домашний LAN):

На устройстве-маршрутизаторе:

```bash
sudo tailscale set --advertise-routes=192.168.1.0/24
```

Одобрите маршрут в админ-консоли. Другие устройства смогут обращаться к хостам `192.168.1.x`.

### Диагностика сети

```bash
tailscale status           # список подключённых устройств
tailscale netcheck         # проверка NAT, задержка DERP-реле
tailscale ping <устройство>  # проверка прямого соединения
tailscale debug netmap     # полная карта сети (подробно)
```

## Взаимодействие с xray/sing-box

Tailscale и xray/sing-box работают на разных сетевых интерфейсах:
- **Tailscale**: TUN-интерфейс `tailscale0`, маршруты `100.64.0.0/10` (CGNAT-диапазон)
- **xray**: SOCKS/HTTP-прокси на уровне приложений (без конфликта TUN)
- **sing-box**: собственный TUN-интерфейс с раздельной маршрутизацией

Если TUN sing-box активен, убедитесь, что его правила маршрутизации **исключают** `100.64.0.0/10`, чтобы не перехватывать трафик Tailscale.

## Истечение ключа и повторная аутентификация

Ключи Tailscale истекают через **180 дней** по умолчанию. При истечении:

1. Устройство тихо отключается от tailnet
2. `tailscale status` показывает "Expired"
3. Повторная аутентификация:

```bash
sudo tailscale up --accept-dns=false
```

Проверить дату истечения ключа:

```bash
tailscale status --json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('Self',{}).get('KeyExpiry','unknown'))"
```

**Совет**: установите напоминание в календаре на 170-й день после аутентификации.

Чтобы отключить истечение ключа для устройства (полезно для постоянно работающих серверов):
1. Перейдите на [login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines)
2. Нажмите меню устройства (⋯) → **Disable key expiry**

## Устранение неполадок

| Проблема | Диагностика | Решение |
|----------|-------------|---------|
| `tailscale status` показывает "Stopped" | Служба не запущена | `sudo systemctl start tailscaled` |
| Не резолвятся имена `*.ts.net` | Отсутствует stub-зона Unbound | Проверьте `unbound-control list_stubs \| grep ts.net`; повторите `just apply` |
| Медленное соединение с пирами | Используется DERP-реле (UDP заблокирован) | `tailscale netcheck` — проверьте возможность прямого соединения |
| Ключ истёк | 180-дневный цикл | `sudo tailscale up --accept-dns=false` |
| Локальный DNS сломался после Tailscale | Запуск без `--accept-dns=false` | `sudo tailscale set --accept-dns=false`, затем `sudo systemctl restart systemd-resolved` |
| `tailscaled` не запускается | Конфликт порта или устаревшее состояние | Проверьте `journalctl -u tailscaled -n 50`; при необходимости удалите `/var/lib/tailscale/tailscaled.state` |
