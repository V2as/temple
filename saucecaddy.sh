#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Использование: $0 domain1.com domain2.com"
  exit 1
fi

DOMAIN1=$1
DOMAIN2=$2

# Создаем Caddyfile
cat > Caddyfile <<EOF
{
    email admin@example.com
}

:80 {
    redir https://{host}{uri}
}

$DOMAIN1 {
    reverse_proxy 127.0.0.1:10000
}

$DOMAIN2 {
    reverse_proxy 127.0.0.1:12000
}
EOF

# Создаем docker-compose.yml
cat > docker-compose.yml <<EOF
version: "3.9"

services:
  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
EOF

echo "Файлы Caddyfile и docker-compose.yml успешно созданы."
