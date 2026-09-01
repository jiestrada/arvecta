#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_DIR="/opt/arvecta/source"
NGINX_AVAILABLE="/etc/nginx/sites-available/arvecta"
NGINX_ENABLED="/etc/nginx/sites-enabled/arvecta"
CERT_FILE="/etc/arvecta/tls/origin-cert.pem"
CERT_KEY="/etc/arvecta/tls/origin-key.pem"

log() { printf '\n[ARVECTA CLOUDFLARE] %s\n' "$*"; }
fail() { printf '\n[ARVECTA CLOUDFLARE][ERROR] %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || fail "Ejecuta este script con sudo."
[[ -d "$SOURCE_DIR/.git" ]] || fail "No existe $SOURCE_DIR. Despliega ARVECTA primero."
[[ -f "$CERT_FILE" ]] || fail "No existe $CERT_FILE"
[[ -f "$CERT_KEY" ]] || fail "No existe $CERT_KEY"

log "Sincronizando infraestructura Cloudflare desde GitHub"
git -C "$SOURCE_DIR" fetch --prune origin main
git -C "$SOURCE_DIR" checkout -B main origin/main
git -C "$SOURCE_DIR" reset --hard origin/main

log "Validando certificado Cloudflare Origin CA"
openssl x509 -in "$CERT_FILE" -noout -subject -issuer -dates
openssl x509 -in "$CERT_FILE" -noout -checkhost arvecta.mx >/dev/null || fail "El certificado no cubre arvecta.mx"
openssl x509 -in "$CERT_FILE" -noout -checkhost www.arvecta.mx >/dev/null || fail "El certificado no cubre www.arvecta.mx"
openssl pkey -in "$CERT_KEY" -noout >/dev/null
CERT_PUB="$(openssl x509 -in "$CERT_FILE" -pubkey -noout | openssl pkey -pubin -outform der 2>/dev/null | sha256sum | awk '{print $1}')"
KEY_PUB="$(openssl pkey -in "$CERT_KEY" -pubout -outform der 2>/dev/null | sha256sum | awk '{print $1}')"
[[ "$CERT_PUB" == "$KEY_PUB" ]] || fail "El certificado y la llave privada no corresponden."

log "Instalando configuración Nginx HTTPS con Cloudflare Origin CA"
install -m 0644 "$SOURCE_DIR/deploy/nginx/arvecta-cloudflare.conf" "$NGINX_AVAILABLE"
ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
nginx -t
systemctl reload nginx

log "Validando HTTPS directamente contra el origin"
curl --noproxy '*' -kfsS --resolve arvecta.mx:443:127.0.0.1 https://arvecta.mx/health/live | sed 's/^/[origin-https] /'
printf '\n'
curl --noproxy '*' -kfsSI --resolve www.arvecta.mx:443:127.0.0.1 https://www.arvecta.mx/ | sed -n '1,6p' | sed 's/^/[www-origin] /'

log "CLOUDFLARE ORIGIN TLS SUCCESS"
echo "CERT=$CERT_FILE"
echo "KEY=$CERT_KEY"
echo "NEXT=Cloudflare: Universal SSL Active + Full (strict)."
