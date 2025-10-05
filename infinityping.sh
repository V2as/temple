#!/bin/bash

# Проверка наличия аргумента
if [ $# -eq 0 ]; then
    echo "Использование: $0 <IP_адрес>"
    echo "Пример: $0 8.8.8.8"
    exit 1
fi

IP_ADDRESS=$1
SERVICE_NAME="ping-monitor-${IP_ADDRESS//./-}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_PATH="/usr/local/bin/${SERVICE_NAME}.sh"

# Проверка прав суперпользователя
if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: Этот скрипт должен запускаться с правами root"
    exit 1
fi

# Создание скрипта ping'а
cat > "$SCRIPT_PATH" << EOF
#!/bin/bash
while true; do
    if ping -c 1 $IP_ADDRESS > /dev/null 2>&1; then
        echo "\$(date): Ping to $IP_ADDRESS - SUCCESS"
    else
        echo "\$(date): Ping to $IP_ADDRESS - FAILED"
    fi
    sleep 5
done
EOF

# Установка прав на скрипт
chmod +x "$SCRIPT_PATH"

# Создание systemd сервиса
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Ping Monitor for $IP_ADDRESS
After=network.target

[Service]
Type=simple
ExecStart=$SCRIPT_PATH
Restart=always
RestartSec=3
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка systemd и запуск сервиса
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

echo "Сервис $SERVICE_NAME успешно создан и запущен!"
echo "IP адрес: $IP_ADDRESS"
echo "Файл сервиса: $SERVICE_FILE"
echo "Скрипт: $SCRIPT_PATH"
echo ""
echo "Команды для управления:"
echo "  systemctl status $SERVICE_NAME"
echo "  systemctl stop $SERVICE_NAME"
echo "  systemctl start $SERVICE_NAME"
echo "  journalctl -u $SERVICE_NAME -f"
