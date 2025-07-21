#!/bin/bash

# Проверка наличия аргументов
if [ $# -eq 0 ]; then
    echo "Usage: $0 <port1> [port2] [port3] ..."
    echo "Example: $0 8080 2086 2087 2095"
    exit 1
fi

# Определение сетевых интерфейсов
WAN_IFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
LAN_IFACE=$(ip link | awk -F': ' '/^[0-9]+: /{print $2}' | grep -v lo | grep -v "$WAN_IFACE" | head -n 1)

# Проверка определения интерфейсов
if [ -z "$WAN_IFACE" ] || [ -z "$LAN_IFACE" ]; then
    echo "Error: Could not determine network interfaces."
    echo "WAN interface: $WAN_IFACE"
    echo "LAN interface: $LAN_IFACE"
    exit 1
fi

echo "Detected WAN interface: $WAN_IFACE"
echo "Detected LAN interface: $LAN_IFACE"

# Настройка NAT
iptables -t nat -A PREROUTING -i "$LAN_IFACE" -p tcp --dport 80 -j DNAT --to-destination 192.168.2.1:3128
iptables -t nat -A PREROUTING -i "$LAN_IFACE" -p tcp --dport 443 -j DNAT --to-destination 192.168.2.1:3127
iptables -t nat -A PREROUTING -i "$LAN_IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 3128
iptables -t nat -A PREROUTING -i "$LAN_IFACE" -p tcp --dport 443 -j REDIRECT --to-ports 3127
iptables -t nat -A POSTROUTING -o "$WAN_IFACE" -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.2.0/24 -o "$WAN_IFACE" -j MASQUERADE

# Базовые политики
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Разрешаем необходимые порты
iptables -A INPUT -p tcp --dport 3127 -j ACCEPT

# Блокировка BitTorrent и подобного трафика
for string in "BitTorrent" "BitTorrent protocol" "peer_id=" ".torrent" \
              "announce.php?passkey=" "torrent" "announce" "info_hash" \
              "get_peers" "announce_peer" "find_node"; do
    iptables -A FORWARD -m string --string "$string" --algo bm --to 65535 -j DROP
done

# Разрешаем доступ к указанным портам
for port in "$@"; do
    iptables -A FORWARD -s 192.168.2.0/24 -p tcp --sport 1024:65535 --dport "$port" -j ACCEPT
    echo "Port $port added to allowed list"
done

# Стандартные порты WHM/cPanel (можно закомментировать, если не нужны)
DEFAULT_PORTS="2086 2087 2095"
for port in $DEFAULT_PORTS; do
    iptables -A FORWARD -s 192.168.2.0/24 -p tcp --sport 1024:65535 --dport "$port" -j ACCEPT
done

# Блокируем все остальные порты
iptables -A FORWARD -s 192.168.2.0/24 -p tcp --sport 1024:65535 --dport 1024:65535 -j REJECT --reject-with icmp-port-unreachable
iptables -A FORWARD -s 192.168.2.0/24 -p udp --sport 1024:65535 --dport 1024:65535 -j REJECT --reject-with icmp-port-unreachable

echo "Firewall rules configured successfully."
echo "Allowed ports: $@ $DEFAULT_PORTS"
echo "WAN interface: $WAN_IFACE"
echo "LAN interface: $LAN_IFACE"
