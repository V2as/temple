#!/bin/bash

CONFIG_FILE="/opt/amnezia/awg/wg0.conf"
SERVICE_FILE="/etc/systemd/system/black.service"

MASK=$(grep -oP 'Address\s*=\s*\K[^\s]+' $CONFIG_FILE)
PORT=$(grep -oP 'ListenPort\s*=\s*\K\d+' $CONFIG_FILE)

IPTABLES_RULES="iptables -t nat -A POSTROUTING -s $MASK -o ens3 -j MASQUERADE; iptables -A INPUT -p udp -m udp --dport $PORT -j ACCEPT; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT;"

echo "[Unit]
Description=WireGuard via wg-quick
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/wg-quick up /opt/amnezia/awg/wg0.conf
ExecStartPost=/bin/bash -c '$IPTABLES_RULES'
ExecStop=/usr/bin/wg-quick down /opt/amnezia/awg/wg0.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" > $SERVICE_FILE

systemctl daemon-reload

systemctl enable black.service
systemctl start black.service
