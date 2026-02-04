#!/bin/bash

# Пути к зависимостям и конфигу
CONFIG_DIR="/var/home/neg/.gemini/tmp/salt_config"

# Проверка на наличие sudo (для изменения системных настроек)
if [ "$EUID" -ne 0 ]; then
  echo "Внимание: скрипт запущен не от root. Системные изменения (timezone, pkg, service) могут не сработать."
  echo "Рекомендуется: sudo -E ./apply_config.sh $@"
fi

# Режим запуска
ACTION="state.sls"
STATE="system_description"

if [[ "$1" == "--dry-run" ]]; then
  echo "--- Запуск в режиме тестирования (изменения не будут применены) ---"
  python3.14 /var/home/neg/src/salt/run_salt.py \
    --config-dir="${CONFIG_DIR}" \
    --local ${ACTION} ${STATE} test=True
else
  echo "--- Применение конфигурации ---"
  python3.14 /var/home/neg/src/salt/run_salt.py \
    --config-dir="${CONFIG_DIR}" \
    --local ${ACTION} ${STATE}
fi
