#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${KARDEX_DOMAIN:-kardexdigital.duckdns.org}"
DUCK_TOKEN="${DUCK_TOKEN:-}"
REPO_URL="${KARDEX_REPO:-https://github.com/Riuyi231/kardex-cloud-server.git}"
APP_DIR="/opt/kardex-cloud-server"
DATA_DIR="/var/lib/kardex"
PORT="18010"

echo "=== KARDEX Cloud Server — Setup ==="
echo "Domain:  $DOMAIN"
echo ""

# 1. Node.js 22 LTS (necesita >= 22.5 para la base de datos integrada)
NODE_MAJOR=$(node -v 2>/dev/null | sed 's/^v//;s/\..*$//' || true)
NODE_MINOR=$(node -v 2>/dev/null | sed 's/^v[0-9]*\.//;s/\..*$//' || true)
if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 22 ] || { [ "$NODE_MAJOR" -eq 22 ] && [ "$NODE_MINOR" -lt 5 ]; }; then
  echo "[1/8] Instalando Node.js 22 LTS..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
else
  echo "[1/8] Node.js ya disponible: $(node -v)"
fi

# 2. Caddy (HTTPS)
echo "[2/8] Instalando Caddy..."
if ! command -v caddy >/dev/null 2>&1; then
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl >/dev/null 2>&1 || true
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
  apt-get update
  apt-get install -y caddy
fi
caddy version

# 3. Codigo en $APP_DIR
echo "[3/8] Clonando repo..."
if [ -d "$APP_DIR" ]; then
  cd "$APP_DIR" && git pull
else
  git clone "$REPO_URL" "$APP_DIR"
fi

# 4. Usuario del sistema (no root)
echo "[4/8] Usuario del sistema..."
id -u kardex >/dev/null 2>&1 || useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin kardex
mkdir -p "$DATA_DIR"
chown -R kardex:kardex "$APP_DIR" "$DATA_DIR"

# 5. Dependencias + datos de OCR (como el usuario kardex)
echo "[5/8] Dependencias y datos de Tesseract..."
sudo -u kardex bash -c "cd '$APP_DIR' && npm install --omit=dev --no-audit --no-fund && npm run tessdata"

# 6. .env
echo "[6/8] Configuracion (.env)..."
if [ ! -f "$APP_DIR/.env" ]; then
  JWT_SECRET=$(openssl rand -hex 32)
  cat > "$APP_DIR/.env" <<EOF
PORT=$PORT
DATA_DIR=$DATA_DIR
JWT_SECRET=$JWT_SECRET
LICENSE_KEY=
CORS_ORIGIN=*
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX=120
EOF
  chown kardex:kardex "$APP_DIR/.env"
  echo "  .env creado con JWT_SECRET aleatorio"
else
  echo "  .env existente"
fi

# 7. DuckDNS -> IP publica (si diste el token)
if [ -n "$DUCK_TOKEN" ]; then
  echo "[7/8] Apuntando $DOMAIN a la IP publica..."
  SUBDOMAIN="${DOMAIN%%.duckdns.org}"
  curl -fsS "https://www.duckdns.org/update?domains=$SUBDOMAIN&token=$DUCK_TOKEN&ip=" || echo "  aviso: duckdns no confirmo (revisa el token y reintenta: curl -s 'https://www.duckdns.org/update?domains=$SUBDOMAIN&token=$DUCK_TOKEN&ip=')"
else
  echo "[7/8] DuckDNS: omite (sin DUCK_TOKEN). Apuntalo en https://duckdns.org/domains"
fi

# 8. Servicio systemd + Caddy + firewall
echo "[8/8] Servicio systemd, Caddy y firewall..."
cat >/etc/systemd/system/kardex-cloud.service <<UNIT
[Unit]
Description=KARDEX Cloud Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
Environment=PORT=$PORT
Environment=DATA_DIR=$DATA_DIR
Environment=NODE_ENV=production
ExecStart=/usr/bin/node src/index.js
Restart=always
RestartSec=3
User=kardex

[Install]
WantedBy=multi-user.target
UNIT

mkdir -p /etc/caddy
cat >/etc/caddy/Caddyfile <<CADDY
$DOMAIN {
  reverse_proxy 127.0.0.1:$PORT
}
CADDY

if command -v ufw >/dev/null 2>&1; then
  ufw allow 22/tcp >/dev/null 2>&1 || true
  ufw allow 80/tcp >/dev/null 2>&1 || true
  ufw allow 443/tcp >/dev/null 2>&1 || true
  ufw --force enable >/dev/null 2>&1 || true
fi

systemctl daemon-reload
systemctl enable --now kardex-cloud >/dev/null 2>&1 || true
systemctl enable --now caddy >/dev/null 2>&1 || true
sleep 2
systemctl restart kardex-cloud caddy || true
sleep 3

echo ""
echo "==> Estado"
systemctl --no-pager is-active kardex-cloud
systemctl --no-pager is-active caddy
curl -fsS "http://127.0.0.1:$PORT/api/ping" && echo || echo "  aviso: el servicio local no respondio"
sleep 2
curl -fsS "https://$DOMAIN/api/ping" && echo || echo "  aviso: el HTTPS aun no responde (dns/ https puede tardar un minuto; verifica con: curl https://$DOMAIN/api/ping)"

echo ""
echo "=== LISTO: https://$DOMAIN ==="
echo "Logs: journalctl -u kardex-cloud -f"
echo ""
echo "Faltan 2 pasos manuales:"
echo "  1) Cambiar la contrasena del admin inicial (admin / admin123):"
echo "     app -> Conexion y servidor -> nube -> conectar con admin/admin123, y en Usuarios cambiarla."
echo "  2) Los backups quedan en $DATA_DIR/backups (copialos a otro lugar periodicamente)."