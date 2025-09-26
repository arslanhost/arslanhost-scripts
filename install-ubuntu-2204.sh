#!/usr/bin/env bash
set -euo pipefail

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ASCII Art Logo - ArslanHOST
echo -e "${CYAN}"
cat << "EOF"
    ___                    _            _   _   _   _   _____   _____ 
   / _ \   _ __     __ _   | |_    ___  | | | | | | | | |_   _| |_   _|
  / /_\ \ | '_ \   / _` |  | __|  / _ \ | |_| | | | | |   | |     | |  
 /  _  \ \| | | | | (_| |  | |_  |  __/ |  _  | | |_| |   | |     | |  
/_/ \_\_\_|_| |_|  \__,_|   \__|  \___| |_| |_|  \___/    |_|     |_|  
EOF
echo -e "${NC}"

echo -e "${BOLD}${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}                    ArslanHOST n8n Otomatik Kurulum Scripti${NC}"
echo -e "${BOLD}${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

### ====== KULLANICI DEĞİŞKENLERİ (ENV ile gelecek) ======
: "${CF_API_TOKEN:?CF_API_TOKEN gerekli}"
: "${CF_ZONE_ID:?CF_ZONE_ID gerekli}"
: "${DOMAIN:?DOMAIN gerekli (ör. arslanhost.com)}"
: "${ADMIN_EMAIL:?ADMIN_EMAIL gerekli (ör. admin@arslanhost.com)}"

### ====== OTOMATİK DEĞERLER ======
echo -e "${BOLD}${BLUE}🔧 SİSTEM BİLGİLERİ ALINIYOR...${NC}"
SERVER_IP="$(curl -fsS http://ipv4.icanhazip.com || hostname -I | awk '{print $1}')"
RAND="$(tr -dc 'a-z0-9' </dev/urandom | head -c 12)"
SUBDOMAIN="n8n-${RAND}"
FQDN="${SUBDOMAIN}.${DOMAIN}"

DB_USER="n8n_$(tr -dc a-z0-9 </dev/urandom | head -c 6)"
DB_NAME="n8n"
DB_PASS="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24)"
JWT_SECRET="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)"
GENERIC_TIME_WAIT=5

echo -e "${GREEN}✅ Sunucu IP:${NC} ${SERVER_IP}"
echo -e "${GREEN}✅ n8n FQDN:${NC} ${FQDN}"
echo -e "${GREEN}✅ Cloudflare Zone:${NC} ${CF_ZONE_ID}"
echo ""

### ====== ÖN HAZIRLIK ======
echo -e "${BOLD}${BLUE}📦 SİSTEM GÜNCELLEMELERİ YAPILIYOR...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y >/dev/null
echo -e "${GREEN}✅ Sistem güncellemeleri tamamlandı${NC}"

echo -e "${YELLOW}📦 Gerekli paketler yükleniyor...${NC}"
apt-get install -y curl jq ca-certificates dnsutils ufw chrony >/dev/null
echo -e "${GREEN}✅ Gerekli paketler yüklendi${NC}"

# Docker & compose plugin
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${YELLOW}🐳 Docker yükleniyor...${NC}"
  apt-get install -y docker.io docker-compose-plugin >/dev/null
  systemctl enable --now docker
  echo -e "${GREEN}✅ Docker yüklendi ve başlatıldı${NC}"
else
  echo -e "${GREEN}✅ Docker zaten yüklü${NC}"
fi

# UFW (80/443 açık, IPv6 açık)
echo -e "${YELLOW}🔥 Firewall ayarları yapılıyor...${NC}"
sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw || true
ufw allow 80,443/tcp >/dev/null || true
ufw --force enable >/dev/null || true
echo -e "${GREEN}✅ Firewall ayarları tamamlandı${NC}"

# Saat senkronu
echo -e "${YELLOW}⏰ Zaman senkronizasyonu ayarlanıyor...${NC}"
systemctl enable --now chrony >/dev/null || true
echo -e "${GREEN}✅ Zaman senkronizasyonu ayarlandı${NC}"

### ====== KLASÖRLER ======
echo -e "${BOLD}${BLUE}📁 KLASÖR YAPISI OLUŞTURULUYOR...${NC}"
mkdir -p /opt/n8n/caddy /opt/n8n/caddy_data /opt/n8n/caddy_config
cd /opt/n8n
echo -e "${GREEN}✅ Klasör yapısı oluşturuldu${NC}"

### ====== .env (n8n & reverse proxy) ======
echo -e "${YELLOW}⚙️  n8n yapılandırma dosyası oluşturuluyor...${NC}"
cat > /opt/n8n/.env <<EOF
# --- n8n env ---
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=${DB_NAME}
DB_POSTGRESDB_USER=${DB_USER}
DB_POSTGRESDB_PASSWORD=${DB_PASS}

N8N_HOST=${FQDN}
WEBHOOK_URL=https://${FQDN}/

N8N_ENCRYPTION_KEY=${JWT_SECRET}
N8N_DIAGNOSTICS_ENABLED=false
N8N_PERSONALIZATION_ENABLED=false
EOF

# Caddy için domain env (compose içine enjekte edeceğiz)
echo "BASE_DOMAIN=${FQDN}" > /opt/n8n/.env.local
echo -e "${GREEN}✅ n8n yapılandırması tamamlandı${NC}"

### ====== Docker Compose ======
echo -e "${YELLOW}🐳 Docker Compose dosyası oluşturuluyor...${NC}"
cat > /opt/n8n/docker-compose.yml <<'YAML'
services:
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres-1
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${DB_POSTGRESDB_DATABASE}
      POSTGRES_USER: ${DB_POSTGRESDB_USER}
      POSTGRES_PASSWORD: ${DB_POSTGRESDB_PASSWORD}
    volumes:
      - ./dbdata:/var/lib/postgresql/data

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n-n8n-1
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "5678:5678"   # iç test için; internetten erişim Caddy üzerinden olacak
    depends_on:
      - postgres
    volumes:
      - ./files:/files

  caddy:
    image: caddy:2-alpine
    container_name: n8n-caddy-1
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    environment:
      - BASE_DOMAIN=${BASE_DOMAIN}
      - ADMIN_EMAIL=${ADMIN_EMAIL}
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile
      - ./caddy_data:/data
      - ./caddy_config:/config
    depends_on:
      - n8n
YAML
echo -e "${GREEN}✅ Docker Compose dosyası oluşturuldu${NC}"

### ====== Caddyfile (başlangıçta STAGING CA ile) ======
echo -e "${YELLOW}🌐 Caddy reverse proxy yapılandırması...${NC}"
cat > /opt/n8n/caddy/Caddyfile <<'CADDY'
{
  email {env.ADMIN_EMAIL}
}

{$BASE_DOMAIN} {
  # İlk etapta staging CA; script ileride production'a alacak
  acme_ca https://acme-staging-v02.api.letsencrypt.org/directory

  encode gzip zstd
  reverse_proxy n8n:5678
}
CADDY

chown -R 1000:1000 /opt/n8n/caddy_data /opt/n8n/caddy_config || true
echo -e "${GREEN}✅ Caddy yapılandırması tamamlandı${NC}"

### ====== Cloudflare A kaydı (DNS only) ======
echo -e "${BOLD}${BLUE}☁️  CLOUDFLARE DNS KAYDI OLUŞTURULUYOR...${NC}"
echo -e "${YELLOW}Cloudflare DNS kaydı oluşturuluyor/güncelleniyor...${NC}"
EXIST_ID="$(curl -fsS -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=${FQDN}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" | jq -r '.result[0].id // empty')"

if [ -z "${EXIST_ID}" ]; then
  CF_RES=$(
    curl -fsS -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"${FQDN}\",\"content\":\"${SERVER_IP}\",\"ttl\":120,\"proxied\":false}"
  )
else
  CF_RES=$(
    curl -fsS -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${EXIST_ID}" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"${FQDN}\",\"content\":\"${SERVER_IP}\",\"ttl\":120,\"proxied\":false}"
  )
fi
echo "$CF_RES" | jq '.success,.errors' || true
echo -e "${GREEN}✅ Cloudflare DNS kaydı oluşturuldu${NC}"

### ====== DNS propagasyonu (en az 1 resolver doğru derse yeter) ======
echo -e "${BOLD}${BLUE}🌐 DNS PROPAGASYONU BEKLENİYOR...${NC}"
echo -e "${YELLOW}DNS propagasyonu bekleniyor (1.1.1.1 / 8.8.8.8 / 9.9.9.9)...${NC}"
OK="no"
for _ in $(seq 1 48); do
  A1="$(dig +short @1.1.1.1 "${FQDN}" A | tail -n1)"
  A2="$(dig +short @8.8.8.8 "${FQDN}" A | tail -n1)"
  A3="$(dig +short @9.9.9.9 "${FQDN}" A | tail -n1)"
  printf "  1.1.1.1=%-15s  8.8.8.8=%-15s  9.9.9.9=%-15s\r" "${A1:-x}" "${A2:-x}" "${A3:-x}"
  if [ "${A1}" = "${SERVER_IP}" ] || [ "${A2}" = "${SERVER_IP}" ] || [ "${A3}" = "${SERVER_IP}" ]; then
    OK="yes"; echo; echo -e "${GREEN}✅ DNS OK: ${FQDN} -> ${SERVER_IP}${NC}"; break
  fi
  sleep "${GENERIC_TIME_WAIT}"
done
[ "${OK}" != "yes" ] && echo -e "${YELLOW}⚠️  DNS tam yayılmamış görünüyor; yine de deneyeceğim...${NC}"

### ====== Docker start (staging sertifika) ======
echo -e "${BOLD}${BLUE}🐳 DOCKER SERVİSLERİ BAŞLATILIYOR...${NC}"
echo -e "${YELLOW}Docker compose up (staging CA ile)...${NC}"
docker compose pull >/dev/null || true
docker compose down >/dev/null || true
docker compose up -d
echo -e "${GREEN}✅ Docker servisleri başlatıldı${NC}"

# Staging sertifika bekle (90 sn)
echo -e "${YELLOW}🔒 Staging sertifika bekleniyor...${NC}"
ST_OK="no"
for _ in $(seq 1 18); do
  if docker logs n8n-caddy-1 --tail=200 2>/dev/null | grep -qiE "certificate(s)? obtained|obtained certificate"; then
    ST_OK="yes"; echo -e "${GREEN}✅ STAGING OK.${NC}"; break
  fi
  sleep 5
done

### ====== Production CA'ya geç ======
echo -e "${BOLD}${BLUE}🔒 PRODUCTION SSL SERTİFİKASI ALINIYOR...${NC}"
echo -e "${YELLOW}Production CA'ya geçiliyor...${NC}"
sed -i 's#acme-staging-v02.api.letsencrypt.org/directory#acme-v02.api.letsencrypt.org/directory#g' /opt/n8n/caddy/Caddyfile
docker compose down >/dev/null || true
docker compose up -d

# Production sertifika bekle (120 sn)
echo -e "${YELLOW}🔒 Production sertifika bekleniyor...${NC}"
PR_OK="no"
for _ in $(seq 1 24); do
  if docker logs n8n-caddy-1 --tail=200 2>/dev/null | grep -qiE "certificate(s)? obtained|obtained certificate"; then
    PR_OK="yes"; echo -e "${GREEN}✅ PRODUCTION OK.${NC}"; break
  fi
  sleep 5
done

### ====== HTTP/HTTPS doğrulama ======
echo -e "${BOLD}${BLUE}🌐 BAĞLANTI TESTLERİ YAPILIYOR...${NC}"
echo -e "${YELLOW}HTTP kontrol:${NC}"
curl -I --max-time 10 "http://${FQDN}" || true
echo -e "${YELLOW}HTTPS kontrol:${NC}"
curl -I --max-time 20 "https://${FQDN}" || true

echo ""
echo -e "${BOLD}${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}                           🎉 KURULUM TAMAMLANDI! 🎉${NC}"
echo -e "${BOLD}${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}${CYAN}📋 KURULUM DETAYLARI:${NC}"
echo -e "${GREEN}🌐 n8n URL:${NC} https://${FQDN}"
echo -e "${GREEN}🗄️  Postgres:${NC} ${DB_NAME} / ${DB_USER} / ${DB_PASS}"
echo -e "${GREEN}🔐 n8n Encryption:${NC} ${JWT_SECRET}"
echo ""
echo -e "${YELLOW}⚠️  İlk dakikalarda tarayıcı/DNS cache nedeniyle uyarı görebilirsiniz; kısa sürede düzelir.${NC}"
echo ""
echo -e "${BOLD}${PURPLE}📞 DESTEK:${NC}"
echo -e "${WHITE}Web: https://arslanhost.com${NC}"
echo -e "${WHITE}E-posta: support@arslanhost.com${NC}"
echo ""
