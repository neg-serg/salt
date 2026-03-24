# Безопасный rollout Zapret2

## Обзор

Этот репозиторий сначала управляет `zapret2` в режиме безопасного rollout. По умолчанию workflow подготавливает пакет, конфиг, unit и helper-скрипт без изменения живой обработки трафика.

## Граница по умолчанию

- `prepare`: описывает управляемую поверхность Zapret2
- `preflight`: собирает prerequisites, конфликты и rollback inputs
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
- собранные rollback inputs; и
- блокировка активации без явного approval.

## Операторский runbook

Неразрушающий review path:

```bash
scripts/zapret2-rollout.sh capture-rollback
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

Workflow отката:

```bash
scripts/zapret2-rollout.sh rollback
sudo scripts/zapret2-rollout.sh rollback --execute-live
scripts/zapret2-rollout.sh revoke-approval
```

## Approval Gate

Для активации нужен явный approval file и файл с rollback inputs. Без них `scripts/zapret2-rollout.sh activate` завершается с отказом.

Даже при наличии approval безопасный review flow по умолчанию не выполняет live activation, пока оператор не запустит этот путь осознанно с нужными входами.

## Примечания

- Текущая ветка безопасно подготавливает ownership и validation для `zapret2`.
- Живой rollout нужно выполнять только после вашего отдельного явного разрешения на destructive changes.
- В helper уже реализованы approval management, rollback capture, smoke checks и rollback preview.
