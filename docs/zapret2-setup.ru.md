# Безопасный rollout Zapret2

## Обзор

Этот репозиторий сначала управляет `zapret2` в режиме безопасного rollout. По умолчанию workflow подготавливает пакет, конфиг, unit и helper-скрипт без изменения живой обработки трафика.

## Граница по умолчанию

- `prepare`: описывает управляемую поверхность Zapret2
- `preflight`: собирает prerequisites и конфликты
- `preview`: показывает, что затронет активация
- `activate`: закрыт явным approval gate и по умолчанию остаётся review-first

Пока явное подтверждение не выдано, workflow не должен:

- включать или запускать `zapret2.service`;
- менять живые firewall или packet-handling правила; или
- автоматически останавливать или перенастраивать существующие proxy/network-компоненты.

## Управляемые артефакты

- Salt state: `states/zapret2.sls`
- Data model: `states/data/zapret2.yaml`
- Шаблон конфига: `states/configs/zapret2.conf.j2`
- Шаблон unit: `states/units/zapret2.service.j2`
- Helper rollout: `scripts/zapret2-rollout.sh`

## Безопасный workflow

Сначала отрендерите и проверьте управляемую поверхность:

```bash
just validate
scripts/zapret2-rollout.sh prepare
scripts/zapret2-rollout.sh preflight
scripts/zapret2-rollout.sh preview
```

Ожидаемый результат:

- список planned artifacts;
- отчёт по prerequisites и conflicts;
- явные требования к approval; и
- блокировка активации без явного approval.

## Операторский runbook

Неразрушающий review path:

```bash
scripts/zapret2-rollout.sh grant-approval --operator "$USER" --reason "approved after preflight review"
scripts/zapret2-rollout.sh preview
scripts/zapret2-rollout.sh smoke
```

Точка входа для live-активации после отдельного явного разрешения:

```bash
sudo systemctl start zapret2.service
```

Проверка после активации:

```bash
scripts/zapret2-rollout.sh smoke
```

## Approval Gate

Для активации нужен явный approval file. Без него `scripts/zapret2-rollout.sh activate` завершается с отказом.

Даже при наличии approval безопасный review flow по умолчанию не выполняет live activation, пока оператор не запустит этот путь осознанно с нужными входами.

## Тестирование и проверка

### Проверка активных профилей после запуска сервиса

```bash
# Убедиться, что nfqws2 запущен с Kyber QUIC профилями:
pgrep -a nfqws2 | grep -c kyber        # ожидается ≥ 2

# Убедиться, что Google TLS профиль развёрнут:
grep tls_clienthello_www_google_com.bin /opt/zapret2/config

# Проверить новые домены в hostlist:
grep yt3.ggpht.com /opt/zapret2/ipset/zapret-hosts-user.txt
```

### Ручная проверка доступности

```bash
# YouTube HTTPS (TLS 1.3):
curl -m 10 -sI https://www.youtube.com | head -3

# YouTube HTTP/3 (QUIC) — требуется curl с поддержкой HTTP/3:
curl --http3 -m 10 -sI https://www.youtube.com | head -3
```

### Полное автоматическое сканирование стратегий (blockcheck2)

```bash
# Сканировать все стратегии для youtube.com в пакетном режиме:
sudo BATCH=1 DOMAINS=youtube.com /opt/zapret2/blockcheck2.sh

# Тестировать только QUIC/HTTP3:
sudo BATCH=1 DOMAINS=youtube.com ENABLE_HTTP=0 ENABLE_HTTPS_TLS12=0 ENABLE_HTTPS_TLS13=0 ENABLE_HTTP3=1 /opt/zapret2/blockcheck2.sh

# Сохранить вывод в лог:
sudo BATCH=1 DOMAINS=youtube.com /opt/zapret2/blockcheck2.sh | tee /tmp/blockcheck.log
```

## Примечания

- Текущая ветка безопасно подготавливает ownership и validation для `zapret2`.
- Живой rollout нужно выполнять только после вашего отдельного явного разрешения на destructive changes.
- В helper уже реализованы approval management, smoke checks и preview output.
