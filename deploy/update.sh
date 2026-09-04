#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# KARDEX Cloud Server - Update / Deploy
# Aplica los ultimos cambios (git pull), garantiza el rate limit, reinicia el
# servicio systemd kardex-cloud y verifica que responda.
#
# Uso (en el VPS, como usuario con sudo):
#   sudo bash deploy/update.sh
# ============================================================================

APP_DIR="/opt/kardex-cloud-server"
SERVICE="kardex-cloud"
SERVICE_USER="kardex"
PORT="$(grep -E '^PORT=' "$APP_DIR/.env" 2>/dev/null | head -n1 | cut -d= -f2)"
PORT="${PORT:-18010}"
RATE_LIMIT_MAX="${RATE_LIMIT_MAX:-2000}"

echo "==> [1/5] Actualizando codigo (git pull) en $APP_DIR"
cd "$APP_DIR"
sudo -u "$SERVICE_USER" git pull --ff-only

echo "==> [2/5] Garantizando RATE_LIMIT_MAX=$RATE_LIMIT_MAX en .env"
ENV_FILE="$APP_DIR/.env"
sudo cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d%H%M%S)"
if grep -qE '^RATE_LIMIT_MAX=' "$ENV_FILE"; then
  sudo sed -i "s/^RATE_LIMIT_MAX=.*/RATE_LIMIT_MAX=$RATE_LIMIT_MAX/" "$ENV_FILE"
else
  echo "RATE_LIMIT_MAX=$RATE_LIMIT_MAX" | sudo tee -a "$ENV_FILE" >/dev/null
fi
sudo chown "$SERVICE_USER":"$SERVICE_USER" "$ENV_FILE"

echo "==> [3/5] Instalando dependencias (npm install)"
sudo -u "$SERVICE_USER" npm install --omit=dev 2>/dev/null || sudo -u "$SERVICE_USER" npm install

echo "==> [4/5] Asegurando servicio systemd $SERVICE"
if [ ! -f "/etc/systemd/system/$SERVICE.service" ]; then
  echo "  (el servicio no existia; se recrea con los valores de setup.sh)"
  sudo tee /etc/systemd/system/$SERVICE.service >/dev/null <<UNIT
[Unit]
Description=KARDEX Cloud Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
Environment=PORT=$PORT
Environment=DATA_DIR=${DATA_DIR:-/var/lib/kardex}
Environment=NODE_ENV=production
ExecStart=/usr/bin/node src/index.js
Restart=always
RestartSec=3
User=$SERVICE_USER

[Install]
WantedBy=multi-user.target
UNIT
  sudo systemctl daemon-reload
  sudo systemctl enable --now $SERVICE
fi

echo "==> [5/5] Reiniciando y verificando"
sudo systemctl restart "$SERVICE"
sleep 3
if curl -fsS "http://127.0.0.1:$PORT/api/ping" >/dev/null 2>&1; then
  echo "  OK: el servicio responde en http://127.0.0.1:$PORT/api/ping"
else
  echo "  AVISO: el servicio local no respondio. Logs: journalctl -u $SERVICE -f"
fi

echo ""
echo "=== LISTO ==="
echo "  servicio:  systemctl status $SERVICE"
echo "  logs:      journalctl -u $SERVICE -f"
echo "  rate limit: ahora $RATE_LIMIT_MAX por ventana ($(grep -E '^RATE_LIMIT_WINDOW_MS=' "$ENV_FILE" | cut -d= -f2)ms)"
