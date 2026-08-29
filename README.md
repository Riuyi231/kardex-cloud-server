# KARDEX Cloud Server

Servidor central de **KARDEX Digital** alojado en Internet. Centraliza la base de
datos y la lectura de cédulas (OCR) para que las PCs de la empresa solo instalen
KARDEX, configuren la nube una vez y trabajen desde cualquier lugar.

- API REST + RPC con autenticación JWT.
- OCR de cédulas (PDF/imagen) con Tesseract + ZXing (barcode).
- Base de datos propia en `data/` (Node >= 22.5, `node:sqlite`), con backups
  automáticos en `data/backups/`.

## Requisitos

- Un VPS con Ubuntu/Debian (512 MB+ de RAM recomendado, 1 GB+ para OCR fluido).
- Un dominio (recomendado: `kardexdigital.duckdns.org` gratuito en https://duckdns.org).
- Puertos **80** y **443** abiertos (HTTPS lo gestiona Caddy).

## Despliegue en el VPS

```bash
sudo KARDEX_DOMAIN=kardexdigital.duckdns.org DUCK_TOKEN=tu-token-de-duckdns bash setup.sh
```

(`DUCK_TOKEN` lo encuentras en https://duckdns.org → tu dominio → token. Es opcional
pero recomendado: apunta el DNS a la IP pública del VPS automáticamente.)

El script (ejecutar como usuario con `sudo`):

1. Instala **Node.js 22 LTS** (verifica >= 22.5, requerido para `node:sqlite`).
2. Instala y configura **Caddy** (HTTPS automático).
3. Clona el repo en `/opt/kardex-cloud-server` e instala dependencias + datos de
   Tesseract (`npm run tessdata`), todo como el usuario del sistema **`kardex`**
   (no corre como root).
4. Crea `.env` con un `JWT_SECRET` aleatorio. Los datos viven en
   `/var/lib/kardex` (base + backups), fuera del código.
5. Apunta **DuckDNS** a la IP pública del VPS (si pasaste `DUCK_TOKEN`).
6. Instala el servicio systemd `kardex-cloud` (auto-arranque + reinicio),
   configura Caddy y abre solo los puertos **22/80/443** en el firewall local
   (ufw).
7. Verifica con `curl` que responde por `http://localhost:18010` y por
   `https://tudominio`.

Configurables:

| Variable | Default | Uso |
| --- | --- | --- |
| `KARDEX_DOMAIN` | `kardexdigital.duckdns.org` | Dominio público del servidor |
| `DUCK_TOKEN` | *(vacío)* | Token del dominio en duckdns (auto-DNS) |
| `KARDEX_REPO` | `https://github.com/Riuyi231/kardex-cloud-server.git` | Repo a clonar |

### Pasos manuales que no hace el script

1. **Firewall del VPS** (GCP/Azure/AWS): abrir también a nivel de nube los
   puertos **80** y **443** (además del ufw local), p. ej.:
   ```bash
   gcloud compute firewall-rules create allow-http --allow tcp:80,tcp:443
   ```
2. **Cambiar la contraseña del admin inicial**: la primera vez entra con
   `admin` / `admin123` desde la app (Conexión y servidor → nube → Conectar y
   guardar acceso) y cámbiala en **Usuarios**. No dejes las credenciales por defecto.

## Verificación

```bash
curl https://tudominio/api/ping      # → {"ok":true,"ts":...}
curl -X POST https://tudominio/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
# → {"ok":true,"token":"...","user":{...}}
```

## Operación diaria

- **Logs**: `sudo journalctl -u kardex-cloud -f`
- **Reiniciar**: `sudo systemctl restart kardex-cloud`
- **Actualizar**: `cd /opt/kardex-cloud-server && sudo git pull && sudo chown -R kardex:kardex . && sudo -u kardex npm install --omit=dev --no-audit --no-fund && sudo systemctl restart kardex-cloud`
- **Backups**: se generan en `/var/lib/kardex/backups` (copialos a otro disco de
  forma periódica; por ejemplo `cron` + `scp`).
- **Ver tráfico**: `sudo journalctl -u kardex-cloud | grep "\[API\]"`

## Endpoints

| Método | Ruta | Auth | Uso |
| --- | --- | --- | --- |
| GET | `/api/ping` | — | Salud del servidor |
| POST | `/api/auth/login` | — | Login, devuelve JWT |
| POST | `/api/rpc` | JWT (invitado+) | Operaciones de datos (cliente) |
| POST | `/api/ocr` | JWT (editor+) | OCR de cédulas (archivo PDF/imagen base64) |

## Desarrollo local

```bash
npm install
npm run tessdata
npm start        # http://localhost:18010
```

Prueba rápida del OCR:

```bash
curl -X POST http://localhost:18010/api/auth/login \
  -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}'
# usa el token en el siguiente:
curl -X POST http://localhost:18010/api/ocr \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d "{\"name\":\"cedula.pdf\",\"data\":\"<base64>\"}"
```