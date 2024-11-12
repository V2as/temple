#!/bin/bash
SSL_KEY=$1

SSL_PATH="/var/lib/marzban-node/ssl_client_cert.pem"
touch $SSL_PATH
DOCKER_COMPOSE_PATH="/app/docker-compose.yml"
HAPROXY_CFG_PATH="/etc/haproxy/haproxy.cfg"

sudo apt-get update && sudo apt-get upgrade -y
sudo apt install socat -y && sudo apt install curl socat -y && apt install git -y
sudo mkdir -p /app
git clone https://github.com/Gozargah/Marzban-node /app
# sudo curl -fsSL https://get.docker.com | sh
sudo mkdir -p /var/lib/marzban-node/

rm $DOCKER_COMPOSE_PATH
echo "$SSL_KEY" > $SSL_PATH
echo "services:
  marzban-node:
    image: gozargah/marzban-node:latest
    restart: always
    network_mode: host

    volumes:
      - /var/lib/marzban-node:/var/lib/marzban-node

    environment:
      SSL_CLIENT_CERT_FILE: $SSL_PATH
      SERVICE_PROTOCOL: rest" > $DOCKER_COMPOSE_PATH

apt update
apt install -y haproxy
echo "global
	log /dev/log	local0
	log /dev/log	local1 notice
	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin
	stats timeout 30s
	user haproxy
	group haproxy
	daemon

	# Default SSL material locations
	ca-base /var/lib/marzban/certs
	crt-base /var/lib/marzban/certs

	# See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
	log	global
	mode	http
	option	httplog
	option	dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
	errorfile 400 /etc/haproxy/errors/400.http
	errorfile 403 /etc/haproxy/errors/403.http
	errorfile 408 /etc/haproxy/errors/408.http
	errorfile 500 /etc/haproxy/errors/500.http
	errorfile 502 /etc/haproxy/errors/502.http
	errorfile 503 /etc/haproxy/errors/503.http
	errorfile 504 /etc/haproxy/errors/504.http

listen front
    mode tcp
    bind *:443

    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }

    use_backend reality if { req.ssl_sni -i end telegram.org }
    # Правило ухода на бэкенд panel если SNI sub.example.com

backend reality
    mode tcp
    server srv1 127.0.0.1:12000 send-proxy-v2 tfo" > $HAPROXY_CFG_PATH


sudo docker compose -f $DOCKER_COMPOSE_PATH up -d
docker run --restart=always -itd \
    --name warp_socks_v3 \
    -p 9091:9091 \
    monius/docker-warp-socks:v3
