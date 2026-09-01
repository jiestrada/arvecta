#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_PATH="${ARVECTA_SSH_KEY:-/Users/jose.estrada/Devs/SSH_AI_Regula_Solutions.pem}"
REMOTE_HOST="${ARVECTA_SSH_HOST:-20.83.46.97}"
REMOTE_USER="${ARVECTA_SSH_USER:-jiestrada}"
REMOTE_PORT="${ARVECTA_SSH_PORT:-22}"
CERT_PATH="${ARVECTA_CF_ORIGIN_CERT:-$REPO_DIR/secrets/cloudflare-origin-cert.pem}"
CERT_KEY_PATH="${ARVECTA_CF_ORIGIN_KEY:-$REPO_DIR/secrets/cloudflare-origin-key.pem}"
REMOTE="$REMOTE_USER@$REMOTE_HOST"
SSH=(ssh -p "$REMOTE_PORT" -i "$KEY_PATH" -o IdentitiesOnly=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3)

log() { printf '\n[ARVECTA CLOUDFLARE] %s\n' "$*"; }
fail() { printf '\n[ARVECTA CLOUDFLARE][ERROR] %s\n' "$*" >&2; exit 1; }

[[ -f "$KEY_PATH" ]] || fail "No encuentro la llave SSH: $KEY_PATH"
[[ -f "$CERT_PATH" ]] || fail "No encuentro el certificado Cloudflare Origin CA: $CERT_PATH"
[[ -f "$CERT_KEY_PATH" ]] || fail "No encuentro la llave privada Cloudflare Origin CA: $CERT_KEY_PATH"

log "Probando SSH a $REMOTE:$REMOTE_PORT"
"${SSH[@]}" "$REMOTE" 'echo SSH_OK && hostname && id -un'

log "Transfiriendo certificado y llave privada sin imprimir secretos"
base64 < "$CERT_PATH" | "${SSH[@]}" "$REMOTE" "umask 077; base64 -d > /tmp/arvecta-origin-cert.pem"
base64 < "$CERT_KEY_PATH" | "${SSH[@]}" "$REMOTE" "umask 077; base64 -d > /tmp/arvecta-origin-key.pem"

log "Instalando Cloudflare Origin CA y Nginx HTTPS"
"${SSH[@]}" -t "$REMOTE" \
  "sudo install -d -m 0700 /etc/arvecta/tls && sudo install -m 0644 -o root -g root /tmp/arvecta-origin-cert.pem /etc/arvecta/tls/origin-cert.pem && sudo install -m 0600 -o root -g root /tmp/arvecta-origin-key.pem /etc/arvecta/tls/origin-key.pem && rm -f /tmp/arvecta-origin-cert.pem /tmp/arvecta-origin-key.pem && curl -fsSL https://raw.githubusercontent.com/jiestrada/arvecta/main/deploy/setup-cloudflare-origin.sh | sudo bash"

log "Validación remota final"
"${SSH[@]}" -t "$REMOTE" \
  "sudo nginx -t && sudo systemctl is-active arvecta.service && curl -kfsS --resolve arvecta.mx:443:127.0.0.1 https://arvecta.mx/health/live && echo"

log "CLOUDFLARE ORIGIN TLS COMPLETADO"
echo "Ahora configura Cloudflare SSL/TLS > Overview > Full (strict) cuando Universal SSL esté Active."
