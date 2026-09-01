#!/usr/bin/env bash
set -Eeuo pipefail

KEY_PATH="${ARVECTA_SSH_KEY:-/Users/jose.estrada/Devs/SSH_AI_Regula_Solutions.pem}"
REMOTE_HOST="${ARVECTA_SSH_HOST:-20.83.46.97}"
REMOTE_USER="${ARVECTA_SSH_USER:-jiestrada}"
REMOTE_PORT="${ARVECTA_SSH_PORT:-22}"
REMOTE="$REMOTE_USER@$REMOTE_HOST"
SSH=(ssh -p "$REMOTE_PORT" -i "$KEY_PATH" -o IdentitiesOnly=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3)

log() { printf '\n[ARVECTA TLS] %s\n' "$*"; }
fail() { printf '\n[ARVECTA TLS][ERROR] %s\n' "$*" >&2; exit 1; }

[[ -f "$KEY_PATH" ]] || fail "No encuentro la llave SSH: $KEY_PATH"

log "Probando SSH a $REMOTE:$REMOTE_PORT"
"${SSH[@]}" "$REMOTE" 'echo SSH_OK && hostname && id -un'

log "Configurando certificado TLS y Nginx HTTPS en el servidor"
"${SSH[@]}" -t "$REMOTE" \
  "curl -fsSL https://raw.githubusercontent.com/jiestrada/arvecta/main/deploy/setup-origin-tls.sh | sudo bash"

log "Validación remota final"
"${SSH[@]}" -t "$REMOTE" \
  "sudo nginx -t && sudo systemctl is-active arvecta.service && curl -fsS --resolve arvecta.mx:443:127.0.0.1 https://arvecta.mx/health/live && echo"

log "TLS DEL ORIGIN COMPLETADO"
echo "Ahora verifica en Cloudflare: SSL/TLS > Edge Certificates > Universal SSL = Active; después SSL/TLS > Overview > Full (strict)."
