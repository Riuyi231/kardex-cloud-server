#!/bin/bash
set -e

echo "=== KARDEX Cloud Server — Setup GCP ==="
echo ""

# 1. Instalar Node.js 22 LTS (necesita >= 22.5 para la base de datos integrada)
if ! command -v node &> /dev/null; then
  echo "[1/6] Instalando Node.js 22 LTS..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo "[1/6] Node.js ya instalado: $(node -v)"
fi
NODE_MAJOR=$(node -p "Number(process.versions.node.split('.')[0])")
NODE_MINOR=$(node -p "Number(process.versions.node.split('.')[1])")
if [ "$NODE_MAJOR" -lt 22 ] || { [ "$NODE_MAJOR" -eq 22 ] && [ "$NODE_MINOR" -lt 5 ]; }; then
  echo "ERROR: se necesita Node.js >= 22.5.0 (tienes $(node -v)). Actualiza e inténtalo de nuevo." >&2
  exit 1
fi

# 2. Clonar repo (ajusta URL)
REPO_URL="${KARDEX_REPO:-https://github.com/Riuyi231/kardex-cloud-server.git}"
APP_DIR="/opt/kardex-cloud-server"
echo "[2/6] Clonando repo..."
if [ -d "$APP_DIR" ]; then
  cd "$APP_DIR" && git pull
else
  sudo git clone "$REPO_URL" "$APP_DIR"
fi
cd "$APP_DIR"
sudo chown -R $USER:$USER "$APP_DIR"
npm install --production
npm run tessdata

# 3. .env
mkdir -p "$APP_DIR/data"
if [ ! -f "$APP_DIR/.env" ]; then
  JWT_SECRET=$(openssl rand -hex 32)
  cat > "$APP_DIR/.env" <<EOF
PORT=18010
DATA_DIR=/opt/kardex-cloud-server/data
JWT_SECRET=$JWT_SECRET
LICENSE_KEY=
CORS_ORIGIN=*
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX=120
EOF
  echo "[3/6] Archivo .env creado con JWT_SECRET aleatorio"
else
  echo "[3/6] Archivo .env existente"
fi

# 4. systemd service
echo "[4/6] Creando servicio systemd..."
sudo tee /etc/systemd/system/kardex-cloud.service > /dev/null <<EOF
[Unit]
Description=KARDEX Cloud Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
ExecStart=$(which node) src/index.js
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable kardex-cloud
sudo systemctl restart kardex-cloud

echo "[5/6] Servicio kardex-cloud iniciado"

# 5. Caddy reverse proxy
echo "[6/6] Configurando Caddy reverse proxy..."
if ! command -v caddy &> /dev/null; then
  sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
  sudo apt-get update
  sudo apt-get install caddy
fi

DOMAIN="${KARDEX_DOMAIN:-kardex.duckdns.org}"
sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
$DOMAIN {
    reverse_proxy localhost:18010
}
EOF

sudo systemctl reload caddy

echo ""
echo "=== Listo ==="
echo "Servidor corriendo en: http://localhost:18010"
echo "Domain configurado: $DOMAIN"
echo "Logs: sudo journalctl -u kardex-cloud -f"
echo ""
echo "Pendientes manuales:"
echo "  1) Apuntar el DNS de $DOMAIN a la IP publica del VPS (duckdns: https://duckdns.org/domains)"
echo "  2) Abrir los puertos 80 y 443 en el VPS (GCP: gcloud compute firewall-rules create allow-http --allow tcp:80,tcp:443)"
echo "  3) Cambiar la contrasena del admin inicial: entra a la app -> Conexion y servidor -> nube, con admin / admin123"
echo "     y luego en la app: Usuarios -> cambiar contrasena (o edita el usuario admin)"
echo "  4) Los backups se guardan en $APP_DIR/data/backups al cerrar el servicio"
