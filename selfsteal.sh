#!/bin/bash
SSL_KEY=$1
SELF_STEAL_DOMAIN=$2

SSL_PATH="/var/lib/marzban-node/ssl_client_cert.pem"
touch $SSL_PATH
DOCKER_COMPOSE_PATH="/app/docker-compose.yml"
HAPROXY_CFG_PATH="/etc/haproxy/haproxy.cfg"
NGINX_CFG_PATH="/etc/nginx/nginx.conf"

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

    use_backend reality

backend reality
    mode tcp
    server srv1 127.0.0.1:12000" > $HAPROXY_CFG_PATH

    
apt update
sudo apt install curl gnupg2 ca-certificates lsb-release ubuntu-keyring -y
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
echo -e "Package: nginx*\nPin: origin nginx.org\nPin-Priority: 900" | sudo tee /etc/apt/preferences.d/99-nginx
sudo apt update
sudo apt install nginx -y


cat << "EOF" > "$NGINX_CFG_PATH"
user www-data;
worker_processes auto;
pid /run/nginx.pid;

error_log /var/log/nginx/error.log;

include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384";
    ssl_prefer_server_ciphers on;

    log_format proxlog '$status ($proxy_protocol_addr) $remote_user [$time_local]';
    access_log /var/log/nginx/access.log proxlog;

    gzip on;

    server {
        access_log off;
        listen 127.0.0.1:8081;
        return 204;
    }

    server {
        listen 127.0.0.1:8001 ssl http2 default_server proxy_protocol;
        server_name _;

        set_real_ip_from 127.0.0.1;
        real_ip_header proxy_protocol;

        ssl_reject_handshake on;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_session_timeout 3m;
        ssl_session_cache shared:SSL:3m;

        access_log /var/log/nginx/access.log proxlog;
    }

    server {
        listen 127.0.0.1:8001 ssl http2 proxy_protocol;
        server_name ${SELF_STEAL_DOMAIN};

        set_real_ip_from 127.0.0.1;
        real_ip_header proxy_protocol;

        ssl_certificate /root/.acme.sh/${SELF_STEAL_DOMAIN}_ecc/fullchain.cer;
        ssl_certificate_key /root/.acme.sh/${SELF_STEAL_DOMAIN}_ecc/${SELF_STEAL_DOMAIN}.key;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384";
        ssl_prefer_server_ciphers on;

        ssl_stapling on;
        ssl_stapling_verify on;
        resolver 1.1.1.1 valid=60s;
        resolver_timeout 2s;

        auth_basic "Access restricted, enter login & password";
        auth_basic_user_file /etc/nginx/.htpasswd;

        root /var/mysite;
        index index.html;
    }
}
EOF

escaped_domain=$(printf '%s\n' "$SELF_STEAL_DOMAIN" | sed 's/[\/&]/\\&/g')
sed -i "s/\${SELF_STEAL_DOMAIN}/$escaped_domain/g" "$NGINX_CFG_PATH"


sudo apt install cron socat
curl https://get.acme.sh | sh -s email=ling.ekb@gmail.com
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --issue --standalone -d $SELF_STEAL_DOMAIN --key-file /var/lib/marzban/certs/key.pem  --fullchain-file /var/lib/marzban/certs/fullchain.pem


sudo docker compose -f $DOCKER_COMPOSE_PATH up -d


curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ noble main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
apt-get update && apt-get install cloudflare-warp -y
warp-cli --accept-tos registration new
warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port 9091
warp-cli --accept-tos connect



settings=(
    "net.core.default_qdisc=fq"
    "net.ipv4.tcp_congestion_control=bbr"
    "net.ipv6.conf.all.disable_ipv6 = 1"
    "net.ipv6.conf.default.disable_ipv6 = 1"
    "net.ipv6.conf.lo.disable_ipv6 = 1"
)

for setting in "${settings[@]}"; do
    grep -q "$setting" /etc/sysctl.conf || echo "$setting" >> /etc/sysctl.conf
done

sysctl -p
