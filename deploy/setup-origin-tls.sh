#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_DIR="/opt/arvecta/source"
NGINX_AVAILABLE="/etc/nginx/sites-available/arvecta"
NGINX_ENABLED="/etc/nginx/sites-enabled/arvecta"
CERT_FILE="/etc/letsencrypt/live/arvecta.mx/fullchain.pem"
CERT_KEY="/etc/letsencrypt/live/arvecta.mx/privkey.pem"
EMAIL="contacto@arvecta.mx"

log() { printf '\n[ARVECTA TLS] %s\n' "$*"; }
fail() { printf '\n[ARVECTA TLS][ERROR] %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || fail "Ejecuta este script con sudo."
[[ -d "$SOURCE_DIR/.git" ]] || fail "No existe $SOURCE_DIR. Despliega ARVECTA primero."

log "Sincronizando infraestructura TLS desde GitHub"
git -C "$SOURCE_DIR" fetch --prune origin main
git -C "$SOURCE_DIR" checkout -B main origin/main
git -C "$SOURCE_DIR" reset --hard origin/main

if ! command -v certbot >/dev/null 2>&1; then
  log "Instalando Certbot y plugin Nginx"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y certbot python3-certbot-nginx
fi

nginx -t

if [[ ! -f "$CERT_FILE" || ! -f "$CERT_KEY" ]]; then
  log "Solicitando certificado Let's Encrypt para arvecta.mx y www.arvecta.mx"
  certbot certonly \
    --nginx \
    --non-interactive \
    --agree-tos \
    --no-eff-email \
    --email "$EMAIL" \
    -d arvecta.mx \
    -d www.arvecta.mx
else
  log "Certificado existente detectado; no se solicita uno nuevo"
fi

[[ -f "$CERT_FILE" ]] || fail "No se generó $CERT_FILE"
[[ -f "$CERT_KEY" ]] || fail "No se generó $CERT_KEY"

log "Instalando configuración HTTPS versionada"
install -m 0644 "$SOURCE_DIR/deploy/nginx/arvecta-tls.conf" "$NGINX_AVAILABLE"
ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
nginx -t
systemctl reload nginx

if systemctl list-unit-files certbot.timer >/dev/null 2>&1; then
  systemctl enable --now certbot.timer >/dev/null 2>&1 || true
fi

log "Validando HTTPS directamente contra el origin"
curl -fsS --resolve arvecta.mx:443:127.0.0.1 https://arvecta.mx/health/live | sed 's/^/[origin-https] /'
printf '\n'
curl -fsSI --resolve www.arvecta.mx:443:127.0.0.1 https://www.arvecta.mx/ | sed -n '1,6p' | sed 's/^/[www-origin] /'

log "Certificado instalado"
certbot certificates 2>/dev/null | sed -n '/Certificate Name: arvecta.mx/,+8p'

log "ORIGIN TLS SUCCESS"
echo "CERT=$CERT_FILE"
echo "KEY=$CERT_KEY"
echo "NEXT=En Cloudflare verifica Universal SSL Active y selecciona Full (strict)."
