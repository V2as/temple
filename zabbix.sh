#!/bin/bash

# Использование: ./update_zabbix_conf.sh <IP> <hostname>
CONF_FILE="/etc/zabbix/zabbix_agentd.conf"

if [ $# -ne 2 ]; then
  echo "Использование: $0 <IP> <hostname>"
  exit 1
fi

NEW_IP=$1
NEW_HOSTNAME=$2

# Резервная копия
cp "$CONF_FILE" "${CONF_FILE}.bak_$(date +%F_%T)"

# Текущая строка Server
CURRENT_SERVERS=$(grep -E "^Server=" "$CONF_FILE" | cut -d= -f2)

# Проверяем, есть ли уже IP
if echo "$CURRENT_SERVERS" | grep -qw "$NEW_IP"; then
    UPDATED_SERVERS="$CURRENT_SERVERS"
else
    UPDATED_SERVERS="${CURRENT_SERVERS},${NEW_IP}"
fi

# Обновляем конфиг
sed -i "s|^Server=.*|Server=${UPDATED_SERVERS}|" "$CONF_FILE"
sed -i "s|^StartAgents=.*|StartAgents=4|" "$CONF_FILE"

# Если Hostname уже есть – заменим, иначе добавим в конец
if grep -q "^Hostname=" "$CONF_FILE"; then
    sed -i "s|^Hostname=.*|Hostname=${NEW_HOSTNAME}|" "$CONF_FILE"
else
    echo "Hostname=${NEW_HOSTNAME}" >> "$CONF_FILE"
fi

echo "✅ Конфигурация обновлена:"
echo "   Server=${UPDATED_SERVERS}"
echo "   StartAgents=4"
echo "   Hostname=${NEW_HOSTNAME}"
