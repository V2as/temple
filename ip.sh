#!/bin/bash

# Проверка root-прав
if [ "$(id -u)" -ne 0 ]; then
  echo "Этот скрипт должен запускаться с правами root!" >&2
  exit 1
fi

# Проверка аргумента
if [ -z "$1" ]; then
  echo "Ошибка: Укажите IP-адрес для мониторинга как аргумент!"
  echo "Пример: $0 146.59.126.114"
  exit 1
fi

TARGET_IP="$1"  # IP берется из первого аргумента
WG_CONFIG="/opt/amnezia/awg/wg0.conf"
LOG_FILE="/var/log/amnezia-wg-monitor.log"
SERVICE_NAME="amnezia-wg-monitor"

# 1. Создаем скрипт мониторинга
cat << EOF > /usr/local/bin/amnezia-wg-monitor.sh
#!/bin/bash

TARGET_IP="$TARGET_IP"
WG_CONFIG="$WG_CONFIG"
PING_COUNT=3
CHECK_INTERVAL=2
LOG_FILE="$LOG_FILE"

log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" >> "\$LOG_FILE"
}

while true; do
    if ! ping -c "\$PING_COUNT" "\$TARGET_IP" > /dev/null 2>&1; then
        log "Связь с \$TARGET_IP потеряна, перезапускаем AmneziaWG..."
        
        if ! awg-quick down "\$WG_CONFIG"; then
            log "Ошибка при остановке AmneziaWG!"
        fi
        sleep 1
        if ! awg-quick up "\$WG_CONFIG"; then
            log "Ошибка при запуске AmneziaWG!"
        else
            log "AmneziaWG успешно перезапущен"
        fi
    else
        log "Связь с \$TARGET_IP стабильна"
    fi
    
    sleep "\$CHECK_INTERVAL"
done
EOF

# 2. Даем права на выполнение
chmod +x /usr/local/bin/amnezia-wg-monitor.sh

# 3. Создаем systemd-сервис
cat << EOF > /etc/systemd/system/$SERVICE_NAME.service
[Unit]
Description=AmneziaWG Connection Monitor (Target: $TARGET_IP)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/amnezia-wg-monitor.sh
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# 4. Включаем и запускаем сервис
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

# 5. Создаем лог-файл
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

echo "Установка завершена!"
echo "Мониторинг IP: $TARGET_IP"
echo "Сервис: $SERVICE_NAME"
echo "Логи: tail -f $LOG_FILE"
echo "Управление:"
echo "  systemctl status $SERVICE_NAME"
echo "  journalctl -u $SERVICE_NAME -f"
