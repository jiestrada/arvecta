#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/jiestrada/arvecta.git"
APP_ROOT="/opt/arvecta"
SOURCE_DIR="$APP_ROOT/source"
RELEASES_DIR="$APP_ROOT/releases"
CURRENT_LINK="$APP_ROOT/current"
ENV_DIR="/etc/arvecta"
ENV_FILE="$ENV_DIR/arvecta.env"
SERVICE_FILE="/etc/systemd/system/arvecta.service"
NGINX_AVAILABLE="/etc/nginx/sites-available/arvecta"
NGINX_ENABLED="/etc/nginx/sites-enabled/arvecta"
CERT_FILE="/etc/letsencrypt/live/arvecta.mx/fullchain.pem"
CERT_KEY="/etc/letsencrypt/live/arvecta.mx/privkey.pem"
APP_PORT="5088"
RUNTIME_ROOT="/opt/dotnet10"
RUNTIME_BIN="$RUNTIME_ROOT/dotnet"
SDK_ROOT="$APP_ROOT/.dotnet-sdk"
SDK_BIN="$SDK_ROOT/dotnet"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RELEASE_DIR="$RELEASES_DIR/$TIMESTAMP"

log() { printf '\n[ARVECTA] %s\n' "$*"; }
fail() { printf '\n[ARVECTA][ERROR] %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || fail "Ejecuta este script con sudo."

for cmd in git nginx curl systemctl ss; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Falta el comando requerido: $cmd"
done

[[ -x "$RUNTIME_BIN" ]] || fail "No encuentro el runtime .NET 10 en $RUNTIME_BIN"
RUNTIMES="$($RUNTIME_BIN --list-runtimes 2>/dev/null || true)"
printf '%s\n' "$RUNTIMES" | grep -Eq '^Microsoft\.NETCore\.App 10\.' || fail "No encuentro Microsoft.NETCore.App 10.x en $RUNTIME_ROOT"
printf '%s\n' "$RUNTIMES" | grep -Eq '^Microsoft\.AspNetCore\.App 10\.' || fail "No encuentro Microsoft.AspNetCore.App 10.x en $RUNTIME_ROOT"
RUNTIME_VERSION="$(printf '%s\n' "$RUNTIMES" | awk '/^Microsoft.AspNetCore.App 10\./ {print $2; exit}')"
log "Runtime ASP.NET Core $RUNTIME_VERSION detectado en $RUNTIME_ROOT"

install -d -m 0755 "$APP_ROOT" "$SOURCE_DIR" "$RELEASES_DIR" /var/log/arvecta
install -d -m 0700 "$ENV_DIR"

SDK_VERSION=""
if [[ -x "$SDK_BIN" ]]; then
  SDK_VERSION="$($SDK_BIN --version 2>/dev/null || true)"
fi
if [[ "$SDK_VERSION" != 10.* ]]; then
  log "Instalando SDK .NET 10 aislado para publicación en $SDK_ROOT"
  rm -rf "$SDK_ROOT"
  install -d -m 0755 "$SDK_ROOT"
  INSTALL_SCRIPT="$(mktemp)"
  trap 'rm -f "$INSTALL_SCRIPT"' EXIT
  curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$INSTALL_SCRIPT"
  bash "$INSTALL_SCRIPT" --channel 10.0 --install-dir "$SDK_ROOT" --no-path
  rm -f "$INSTALL_SCRIPT"
  trap - EXIT
  SDK_VERSION="$($SDK_BIN --version)"
fi
[[ "$SDK_VERSION" == 10.* ]] || fail "No fue posible disponer de un SDK .NET 10.x para publicar ARVECTA."
log "SDK .NET $SDK_VERSION listo en $SDK_BIN"

export DOTNET_ROOT="$SDK_ROOT"
export PATH="$SDK_ROOT:$PATH"

if ss -ltnp | grep -q ":${APP_PORT} " && ! systemctl is-active --quiet arvecta.service 2>/dev/null; then
  fail "El puerto ${APP_PORT} ya está ocupado por otro proceso. No se modificó nada."
fi

log "Preparando directorios"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
  rm -rf "$SOURCE_DIR"
  git clone "$REPO_URL" "$SOURCE_DIR"
fi

log "Sincronizando main desde GitHub"
git -C "$SOURCE_DIR" fetch --prune origin main
git -C "$SOURCE_DIR" checkout -B main origin/main
git -C "$SOURCE_DIR" reset --hard origin/main
DEPLOY_SHA="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
printf '%s\n' "$DEPLOY_SHA" > "$APP_ROOT/deployed-sha"

if [[ ! -f "$ENV_FILE" ]]; then
  log "Configurando SMTP de producción"
  read -r -p "Usuario SMTP (AI Regula por ahora): " SMTP_USER
  read -r -s -p "Password SMTP: " SMTP_PASSWORD
  printf '\n'
  [[ -n "$SMTP_USER" ]] || fail "El usuario SMTP no puede quedar vacío."
  [[ -n "$SMTP_PASSWORD" ]] || fail "La contraseña SMTP no puede quedar vacía."

  cat > "$ENV_FILE" <<EOF
ASPNETCORE_ENVIRONMENT=Production
ASPNETCORE_URLS=http://127.0.0.1:${APP_PORT}
EmailSettings__SmtpHost=smtp.ionos.mx
EmailSettings__SmtpPort=465
EmailSettings__Security=SslOnConnect
EmailSettings__SmtpUser=${SMTP_USER}
EmailSettings__SmtpPassword=${SMTP_PASSWORD}
EmailSettings__FromName=ARVECTA Technologies
EmailSettings__FromEmail=info@airegulasolutions.com
EmailSettings__ToEmail=contacto@arvecta.mx
EmailSettings__BccEmail=
EOF
  chmod 0600 "$ENV_FILE"
  chown root:root "$ENV_FILE"
else
  log "Conservando configuración existente en $ENV_FILE"
fi

log "Publicando release $TIMESTAMP con SDK .NET $SDK_VERSION"
install -d -m 0755 "$RELEASE_DIR"
"$SDK_BIN" publish "$SOURCE_DIR/Arvecta.Web.csproj" \
  --configuration Release \
  --output "$RELEASE_DIR" \
  --nologo

chown -R root:root "$RELEASE_DIR"
find "$RELEASE_DIR" -type d -exec chmod 0755 {} +
find "$RELEASE_DIR" -type f -exec chmod 0644 {} +

log "Instalando unidad systemd"
install -m 0644 "$SOURCE_DIR/deploy/systemd/arvecta.service" "$SERVICE_FILE"
systemctl daemon-reload

log "Instalando reverse proxy Nginx"
if [[ -f "$CERT_FILE" && -f "$CERT_KEY" ]]; then
  log "Certificado TLS detectado; conservando HTTPS en deploy"
  install -m 0644 "$SOURCE_DIR/deploy/nginx/arvecta-tls.conf" "$NGINX_AVAILABLE"
  TLS_ENABLED=1
else
  install -m 0644 "$SOURCE_DIR/deploy/nginx/arvecta.conf" "$NGINX_AVAILABLE"
  TLS_ENABLED=0
fi
ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
nginx -t

log "Activando release"
ln -sfn "$RELEASE_DIR" "$CURRENT_LINK.new"
mv -Tf "$CURRENT_LINK.new" "$CURRENT_LINK"

systemctl enable arvecta.service >/dev/null
systemctl restart arvecta.service
nginx -s reload

log "Esperando health checks"
for attempt in {1..20}; do
  if curl -fsS "http://127.0.0.1:${APP_PORT}/health/live" >/dev/null; then
    break
  fi
  sleep 1
  [[ "$attempt" -lt 20 ]] || {
    journalctl -u arvecta.service -n 80 --no-pager || true
    fail "ARVECTA no respondió al health/live."
  }
done

curl -fsS "http://127.0.0.1:${APP_PORT}/health/live" | sed 's/^/[health-live] /'
printf '\n'
curl -fsS "http://127.0.0.1:${APP_PORT}/health/ready" | sed 's/^/[health-ready] /'
printf '\n'
if [[ "$TLS_ENABLED" -eq 1 ]]; then
  curl -fsS --resolve arvecta.mx:443:127.0.0.1 "https://arvecta.mx/health/live" | sed 's/^/[nginx-https] /'
else
  curl -fsS -H 'Host: arvecta.mx' "http://127.0.0.1/health/live" | sed 's/^/[nginx-http] /'
fi
printf '\n'

log "Estado de servicios"
systemctl --no-pager --full status arvecta.service | sed -n '1,18p'
printf '\n'
nginx -t

log "Limpiando releases antiguos (conserva 5)"
mapfile -t OLD_RELEASES < <(find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r | tail -n +6)
for old in "${OLD_RELEASES[@]:-}"; do
  [[ -n "$old" ]] && rm -rf "$RELEASES_DIR/$old"
done

log "DEPLOYMENT SUCCESS"
echo "DEPLOY_SHA=$DEPLOY_SHA"
echo "RUNTIME_VERSION=$RUNTIME_VERSION"
echo "RUNTIME_BIN=$RUNTIME_BIN"
echo "SDK_VERSION=$SDK_VERSION"
echo "SDK_BIN=$SDK_BIN"
echo "APP=http://127.0.0.1:${APP_PORT}"
echo "NGINX_HOST=arvecta.mx"
echo "TLS_ENABLED=$TLS_ENABLED"
echo "ENV_FILE=$ENV_FILE"
echo "NEXT=Si TLS_ENABLED=0 ejecuta deploy/setup-tls-from-mac.sh; después usa Cloudflare Full (strict)."
