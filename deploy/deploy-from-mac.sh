#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_PATH="${ARVECTA_SSH_KEY:-/Users/jose.estrada/Devs/SSH_AI_Regula_Solutions.pem}"
REMOTE_HOST="${ARVECTA_SSH_HOST:-20.83.46.97}"
REMOTE_USER="${ARVECTA_SSH_USER:-jiestrada}"
REMOTE_PORT="${ARVECTA_SSH_PORT:-22}"
LOCAL_SETTINGS="$REPO_DIR/appsettings.Local.json"
REMOTE="$REMOTE_USER@$REMOTE_HOST"
SSH=(ssh -p "$REMOTE_PORT" -i "$KEY_PATH" -o IdentitiesOnly=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3)

log() { printf '\n[ARVECTA] %s\n' "$*"; }
fail() { printf '\n[ARVECTA][ERROR] %s\n' "$*" >&2; exit 1; }

[[ -f "$KEY_PATH" ]] || fail "No encuentro la llave SSH: $KEY_PATH"
[[ -f "$LOCAL_SETTINGS" ]] || fail "No encuentro $LOCAL_SETTINGS. Configura primero SMTP local."
command -v python3 >/dev/null 2>&1 || fail "Se requiere python3 en tu Mac."

TMP_ENV="$(mktemp)"
trap 'rm -f "$TMP_ENV"' EXIT

python3 - "$LOCAL_SETTINGS" > "$TMP_ENV" <<'PY'
import json, sys
p=sys.argv[1]
with open(p, encoding='utf-8') as f:
    data=json.load(f)
email=data.get('EmailSettings', {})
user=email.get('SmtpUser','').strip()
password=email.get('SmtpPassword','')
if not user or not password:
    raise SystemExit('SmtpUser/SmtpPassword están vacíos en appsettings.Local.json')

def q(value):
    value=str(value).replace('\\','\\\\').replace('"','\\"').replace('\n','\\n')
    return f'"{value}"'

values={
 'ASPNETCORE_ENVIRONMENT':'Production',
 'ASPNETCORE_URLS':'http://127.0.0.1:5088',
 'EmailSettings__SmtpHost':'smtp.ionos.mx',
 'EmailSettings__SmtpPort':'465',
 'EmailSettings__Security':'SslOnConnect',
 'EmailSettings__SmtpUser':user,
 'EmailSettings__SmtpPassword':password,
 'EmailSettings__FromName':'ARVECTA Technologies',
 'EmailSettings__FromEmail':'info@airegulasolutions.com',
 'EmailSettings__ToEmail':'contacto@arvecta.mx',
 'EmailSettings__BccEmail':'',
}
for k,v in values.items():
    print(f'{k}={q(v)}')
PY

log "Probando SSH a $REMOTE:$REMOTE_PORT"
"${SSH[@]}" "$REMOTE" 'echo SSH_OK && hostname && id -un'

log "Transfiriendo configuración SMTP sin imprimir secretos"
base64 < "$TMP_ENV" | "${SSH[@]}" "$REMOTE" "umask 077; base64 -d > /tmp/arvecta.env"
"${SSH[@]}" -t "$REMOTE" \
  "sudo install -d -m 0700 /etc/arvecta && sudo install -m 0600 -o root -g root /tmp/arvecta.env /etc/arvecta/arvecta.env && rm -f /tmp/arvecta.env"

log "Ejecutando bootstrap/deploy en servidor"
"${SSH[@]}" -t "$REMOTE" \
  "curl -fsSL https://raw.githubusercontent.com/jiestrada/arvecta/main/deploy/deploy-production.sh | sudo bash"

log "Validación remota"
"${SSH[@]}" -t "$REMOTE" \
  "sudo systemctl is-active arvecta.service && curl -fsS http://127.0.0.1:5088/health/live && echo && curl -fsS http://127.0.0.1:5088/health/ready && echo && curl -fsS -H 'Host: arvecta.mx' http://127.0.0.1/health/live && echo"

log "DEPLOYMENT COMPLETADO"
echo "Siguiente: configurar DNS de arvecta.mx en Cloudflare y TLS Full (strict)."
