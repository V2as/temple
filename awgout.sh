#!/bin/bash
IP=$1
touch /home/awgmode.txt
echo "server" > /home/awgmode.txt
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
apt-get -y update
apt-get -y upgrade
apt-get install -y git software-properties-common python3-launchpadlib gnupg2 linux-headers-$(uname -r) zstd sudo
add-apt-repository -y ppa:amnezia/ppa
apt-get -y update
apt-get -y upgrade
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/00-amnezia.conf
echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
echo net.ipv4.conf.all.src_valid_mark=1 >> /etc/sysctl.conf
sysctl -p
mkdir /app
git clone https://github.com/amnezia-vpn/amneziawg-tools.git /app
apt-get install -y make g++ gcc
/app/amneziawg-tools/src && make && make install
ln -s /app/amneziawg-tools/src/wg /usr/bin/
ln -s /app/amneziawg-tools/src/wg-quick/wg-quick /usr/bin/
apt-get install -y \
    dpkg \
    dumb-init \
    iptables \
    iproute2
update-alternatives --install /sbin/iptables iptables /sbin/iptables-legacy 10 --slave /sbin/iptables-restore iptables-restore /sbin/iptables-legacy-restore --slave /sbin/iptables-save iptables-save /sbin/iptables-legacy-save
rm -f /usr/bin/wg-quick
ln -s /usr/bin/awg-quick /usr/bin/wg-quick
apt-get install amneziawg -y
mkdir -p /opt/amnezia/awg


CONFIG_FILE="/opt/amnezia/awg/wg0.conf"
umask 077 && awg genkey | tee /opt/amnezia/awg/wireguard_server_private_key.key | awg pubkey > /opt/amnezia/awg/wireguard_server_public_key.key && umask 077 && awg genpsk > /opt/amnezia/awg/wireguard_psk.key
PrivateKey=$(cat /opt/amnezia/awg/wireguard_server_private_key.key)
PSK=$(cat /opt/amnezia/awg/wireguard_psk.key)
client_private_key=$(awg genkey)
client_public_key=$(echo $client_private_key | awg pubkey)
H1=$(shuf -i5-2147483647 -n1)
H2=$(shuf -i5-2147483647 -n1)
H3=$(shuf -i5-2147483647 -n1)
H4=$(shuf -i5-2147483647 -n1)
port_number=$((RANDOM % 10000 + 10000))
MASK="10.8.1.0/24"


echo "[Interface]
PrivateKey = $PrivateKey
Address = $MASK
MTU = 1420
ListenPort = $port_number
Jc = 4
Jmin = 20
Jmax = 50
S1 = 28
S2 = 47
H1 = ${H1}
H2 = ${H2}
H3 = ${H3}
H4 = ${H4}
PostUp = iptables -t nat -A POSTROUTING -o `ip route | awk '/default/ {print $5; exit}'` -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o `ip route | awk '/default/ {print $5; exit}'` -j MASQUERADE

[Peer]
PublicKey = HkObM/QgmOHPOySbTv8K9DdR8EdaVt2xv3aeLb8Silk=
Endpoint = $IP:14194
AllowedIPs = 10.8.1.4/24
PersistentKeepalive = 25

[Peer]
PublicKey = $client_public_key
PresharedKey = $PSK
AllowedIPs = 10.8.1.2/32" > $CONFIG_FILE


SERVICE_FILE="/etc/systemd/system/black.service"

echo "[Unit]
Description=WireGuard via wg-quick
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/wg-quick up /opt/amnezia/awg/wg0.conf
ExecStop=/usr/bin/wg-quick down /opt/amnezia/awg/wg0.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" > $SERVICE_FILE

systemctl daemon-reload
systemctl enable black.service
systemctl start black.service

