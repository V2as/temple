#!/bin/bash
set -e

# Возможные пути расположения nginx.service
SERVICE_PATHS=(
    "/etc/systemd/system/nginx.service"
    "/lib/systemd/system/nginx.service"
    "/usr/lib/systemd/system/nginx.service"
    "/usr/local/systemd/system/nginx.service"
)

SERVICE_FILE=""

# Поиск первого существующего файла
for path in "${SERVICE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        SERVICE_FILE="$path"
        break
    fi
done

if [ -z "$SERVICE_FILE" ]; then
    echo "❌ nginx.service не найден в стандартных путях!"
    exit 1
fi

echo "✔ Найден unit-файл: $SERVICE_FILE"

# Функция для добавления строки внутрь секции [Service]
add_to_service_section() {
    local key="$1"
    local value="$2"

    # Проверяем, есть ли уже эта строка
    if grep -qE "^\s*${key}=" "$SERVICE_FILE"; then
        echo "   → Уже есть $key (пропущено)"
    else
        # Проверяем, существует ли секция [Service], если нет - создаем
        if ! grep -q "^\[Service\]" "$SERVICE_FILE"; then
            echo "❌ Секция [Service] не найдена! Добавление невозможно."
            exit 1
        fi
        
        # Вставляем новую строку после секции [Service] или после последней строки внутри секции
        sed -i "/^\[Service\]/a ${key}=${value}" "$SERVICE_FILE"
        echo "   → Добавлено: ${key}=${value}"
    fi
}

echo "Добавляем параметры в секцию [Service]..."
add_to_service_section "Restart" "on-failure"
add_to_service_section "RestartSec" "5s"
add_to_service_section "StartLimitInterval" "60s"
add_to_service_section "StartLimitBurst" "3"

echo "Перезагружаем systemd..."
systemctl daemon-reload
systemctl enable nginx
systemctl restart nginx
echo "✅ Готово! Теперь можно проверить: systemctl cat nginx"
