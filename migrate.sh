#!/bin/bash
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

docker cp amnezia-awg:/opt/amnezia/awg/wireguard_server_private_key.key /opt/amnezia/awg
docker cp amnezia-awg:/opt/amnezia/awg/wireguard_server_public_key.key /opt/amnezia/awg
docker cp amnezia-awg:/opt/amnezia/awg/wireguard_psk.key /opt/amnezia/awg
docker cp amnezia-awg:/opt/amnezia/awg/wg0.conf /opt/amnezia/awg


CONFIG_FILE="/opt/amnezia/awg/wg0.conf"
NEW_CONFIG_FILE="/opt/amnezia/awg/wg0.conf"

MASK=$(grep -oP 'Address\s*=\s*\K[^\s]+' $CONFIG_FILE)

PORT=$(grep -oP 'ListenPort\s*=\s*\K\d+' $CONFIG_FILE)



iptables -t nat -A POSTROUTING -s $MASK -o ens3 -j MASQUERADE; iptables -A INPUT -p udp -m udp --dport $PORT -j ACCEPT; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT;
#iptables -t nat -D POSTROUTING -s $MASK -o ens3 -j MASQUERADE; iptables -D INPUT -p udp -m udp --dport $PORT -j ACCEPT; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT;
iptables-save -t nat
docker stop $(docker ps -q)
docker rm $(docker ps -a -q)

wg-quick up /opt/amnezia/awg/wg0.conf
