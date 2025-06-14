DASH_DOMAIN=$1
SELF_STEAL_DOMAIN=$2

ACME_SS="/root/.acme.sh/$SELF_STEAL_DOMAIN"
ACME_DM_FC="/root/.acme.sh/${DASH_DOMAIN}_ecc/fullchain.cer"   
ACME_DM_KEY="/root/.acme.sh/${DASH_DOMAIN}_ecc/$DASH_DOMAIN.key"
ACME_DM="/root/.acme.sh/${DASH_DOMAIN}_ecc"

HAPROXY_CFG_PATH="/etc/haproxy/haproxy.cfg"
NGINX_CFG_PATH="/etc/nginx/nginx.conf"

sudo apt install cron socat
curl https://get.acme.sh | sh -s email=ling.ekb@gmail.com
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --issue --standalone -d $DASH_DOMAIN --key-file /var/lib/marzban/certs/key.pem  --fullchain-file /var/lib/marzban/certs/fullchain.pem
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --issue --standalone -d $SELF_STEAL_DOMAIN

sudo apt install curl gnupg2 ca-certificates lsb-release ubuntu-keyring -y
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
echo -e "Package: nginx*\nPin: origin nginx.org\nPin-Priority: 900" | sudo tee /etc/apt/preferences.d/99-nginx



sudo apt update

sudo apt install nginx -y
apt install -y haproxy

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
	ca-base $ACME_SS
	crt-base $ACME_SS

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
    acl is_blackstormrage req.ssl_sni -i end $DASH_DOMAIN
    
    tcp-request content accept if HTTP  
    
    use_backend sub if is_blackstormrage
    use_backend panel if is_blackstormrage
    use_backend reality if !is_blackstormrage


backend reality
    mode tcp
    server srv1 127.0.0.1:12000 

backend sub
    mode tcp
    server srv1 127.0.0.1:10000

backend panel
    mode tcp
    server srv1 127.0.0.1:10000" > $HAPROXY_CFG_PATH



curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ noble main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
apt-get update && apt-get install cloudflare-warp -y
warp-cli --accept-tos registration new
warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port 9091
warp-cli --accept-tos connect

systemctl restart nginx
systemctl restart haproxy


echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p


echo 'SUB_PROFILE_TITLE = "BLACKTEMPLE VPN BR"' >> /opt/marzban/.env
echo 'SUB_UPDATE_INTERVAL = "2"' >> /opt/marzban/.env
echo "XRAY_SUBSCRIPTION_URL_PREFIX=\"https://$DASH_DOMAIN\"" >> /opt/marzban/.env
echo "UVICORN_SSL_KEYFILE =\"$ACME_DM_KEY\"" >> /opt/marzban/.env
echo "UVICORN_SSL_CERTFILE =\"$ACME_DM_FC\"" >> /opt/marzban/.env

ACME_DIR="/root/.acme.sh/${DASH_DOMAIN}_ecc"

COMPOSE_FILE="/opt/marzban/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Ошибка: docker-compose.yml не найден"
    exit 1
fi

if grep -q "$ACME_DIR:$ACME_DIR" "$COMPOSE_FILE"; then
    echo "Volume уже существует"
    exit 0
fi

if command -v yq &> /dev/null; then
    yq eval ".services.marzban.volumes += \"$ACME_DIR:$ACME_DIR\"" "$COMPOSE_FILE" > tmp.yml && mv tmp.yml "$COMPOSE_FILE"
else
    sed -i "/volumes:/a \      - $ACME_DIR:$ACME_DIR" "$COMPOSE_FILE"
fi

echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf >/dev/null

