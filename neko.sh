#!/bin/bash
set -e

# =========================
# Colors
# =========================
GREEN='\033[0;32m'
AQUA='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# =========================
# Rollback flags
# =========================
CREATE_DOCKER_COMPOSE=false
CLONE_NEKO_ROOMS=false
CREATE_NGINX_CONFIG=false
CREATE_HTPASSWD=false
OBTAIN_CERTIFICATE=false
CREATE_CRON_JOB=false
CREATE_MANAGE_SCRIPT=false

rollback() {
  echo -e "${RED}\nAn error occurred. Rolling back...${NC}"

  cd /opt/neko-rooms 2>/dev/null || true
  docker compose down || true

  docker network rm neko-rooms-net 2>/dev/null || true
  rm -rf /opt/neko-rooms || true
  rm -f /etc/nginx/sites-available/${DOMAIN}-neko-rooms.conf
  rm -f /etc/nginx/sites-enabled/${DOMAIN}-neko-rooms.conf
  rm -f /etc/nginx/.htpasswd
  systemctl reload nginx || true

  echo -e "${RED}Rollback complete.${NC}"
  exit 1
}

trap rollback ERR

# =========================
# Root check
# =========================
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Run as root.${NC}"
  exit 1
fi

# =========================
# OS check
# =========================
source /etc/os-release
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
  echo -e "${RED}Only Ubuntu/Debian supported.${NC}"
  exit 1
fi

# =========================
# Packages
# =========================
echo -e "${YELLOW}Installing required packages...${NC}"
apt update
apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  dnsutils \
  nginx \
  certbot \
  python3-certbot-nginx \
  apache2-utils \
  cron

# =========================
# Docker
# =========================
if ! command -v docker &>/dev/null; then
  echo -e "${YELLOW}Installing Docker...${NC}"
  curl -fsSL https://get.docker.com | bash
fi

systemctl enable docker
systemctl start docker

# =========================
# Docker Compose v2
# =========================
if ! docker compose version &>/dev/null; then
  echo -e "${YELLOW}Installing Docker Compose v2 plugin...${NC}"
  apt install -y docker-compose-plugin
fi

# =========================
# Inputs
# =========================
read -rp "Domain (example.com): " DOMAIN
read -rp "Email (SSL): " EMAIL
read -rp "Admin user: " ADMIN_USER
read -rsp "Admin password: " ADMIN_PASSWORD
echo
read -rp "Timezone [UTC]: " TIMEZONE
TIMEZONE=${TIMEZONE:-UTC}
read -rp "Room port range [59000-59100]: " ROOM_PORT_RANGE
ROOM_PORT_RANGE=${ROOM_PORT_RANGE:-59000-59100}
read -rp "Docker internal port [8080]: " DOCKER_PORT
DOCKER_PORT=${DOCKER_PORT:-8080}
read -rp "Path prefix [room]: " PATH_PREFIX
PATH_PREFIX=${PATH_PREFIX:-room}

DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n1)

# =========================
# Clone repo
# =========================
echo -e "${YELLOW}Cloning Neko Rooms...${NC}"
git clone https://github.com/m1k1o/neko-rooms.git /opt/neko-rooms
CLONE_NEKO_ROOMS=true
cd /opt/neko-rooms

# =========================
# Docker Compose file
# =========================
echo -e "${YELLOW}Creating docker-compose.yml...${NC}"
cat <<EOF > docker-compose.yml
services:
  neko-rooms:
    image: m1k1o/neko-rooms:latest
    restart: unless-stopped
    environment:
      TZ: "${TIMEZONE}"
      NEKO_ROOMS_MUX: "true"
      NEKO_ROOMS_EPR: "${ROOM_PORT_RANGE}"
      NEKO_ROOMS_NAT1TO1: "${DOMAIN_IP}"
      NEKO_ROOMS_INSTANCE_URL: "https://${DOMAIN}/"
      NEKO_ROOMS_INSTANCE_NETWORK: "neko-rooms-net"
      NEKO_ROOMS_TRAEFIK_ENABLED: "false"
      NEKO_ROOMS_PATH_PREFIX: "/${PATH_PREFIX}/"
      NEKO_ROOMS_STORAGE_ENABLED: "true"
      NEKO_ROOMS_STORAGE_INTERNAL: "/data"
      NEKO_ROOMS_STORAGE_EXTERNAL: "/opt/neko-rooms/data"
    ports:
      - "127.0.0.1:${DOCKER_PORT}:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/neko-rooms/data:/data

networks:
  default:
    name: neko-rooms-net
    attachable: true
EOF

CREATE_DOCKER_COMPOSE=true

# =========================
# Start service
# =========================
docker compose up -d

# =========================
# NGINX
# =========================
echo -e "${YELLOW}Configuring NGINX...${NC}"
cat <<EOF > /etc/nginx/sites-available/${DOMAIN}-neko-rooms.conf
map \$http_upgrade \$connection_upgrade {
  default upgrade;
  '' close;
}

server {
  listen 80;
  server_name ${DOMAIN};

  location ^~ /${PATH_PREFIX}/ {
    proxy_pass http://127.0.0.1:${DOCKER_PORT};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;
  }

  location / {
    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://127.0.0.1:${DOCKER_PORT};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;
  }
}
EOF

ln -sf /etc/nginx/sites-available/${DOMAIN}-neko-rooms.conf /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
CREATE_NGINX_CONFIG=true

# =========================
# Auth
# =========================
htpasswd -cb /etc/nginx/.htpasswd "$ADMIN_USER" "$ADMIN_PASSWORD"
CREATE_HTPASSWD=true

# =========================
# SSL
# =========================
certbot --nginx -d "$DOMAIN" -m "$EMAIL" --agree-tos --non-interactive
OBTAIN_CERTIFICATE=true

# =========================
# Cron
# =========================
cat <<EOF > /etc/cron.d/certbot-renew
0 3 * * * root certbot renew --quiet && systemctl reload nginx
EOF
CREATE_CRON_JOB=true
systemctl restart cron

# =========================
# Finish
# =========================
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}Neko Rooms instalado com sucesso!${NC}"
echo -e "${GREEN}URL: https://${DOMAIN}${NC}"
echo -e "${GREEN}===========================================${NC}"

