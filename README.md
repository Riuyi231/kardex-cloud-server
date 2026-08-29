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
- Un dominio (recomendado: `kardex.duckdns.org` gratuito en https://duckdns.org).
- Puertos **80** y **443** abiertos (HTTPS lo gestiona Caddy).

## Despliegue en el VPS (un comando)

```bash
KARDEX_DOMAIN=kardex.duckdns.org bash deploy/setup.sh
```

El script (debe ejecutarse como usuario con `sudo`):

1. Instala **Node.js 22 LTS** (verifica >= 22.5, requerido para `node:sqlite`).
2. Clona este repo en `/opt/kardex-cloud-server` e instala dependencias + datos
   de Tesseract (`npm run tessdata`).
3. Crea `.env` con un `JWT_SECRET` aleatorio.
4. Instala el servicio systemd `kardex-cloud` (auto-arranque + reinicio).
5. Configura **Caddy** como proxy inverso con HTTPS automático para tu dominio.

Configurables al correrlo:

| Variable | Default | Uso |
| --- | --- | --- |
| `KARDEX_DOMAIN` | `kardex.duckdns.org` | Dominio público del servidor |
| `KARDEX_REPO` | `https://github.com/Riuyi231/kardex-cloud-server.git` | Repo a clonar |

### Pasos manuales que no hace el script

1. **DNS**: en https://duckdns.org apunta tu dominio a la **IP pública** del VPS
   (el VPS normalmente tiene IP fija; configúrala una sola vez, o usa la
   actualización automática por cron/curl de duckdns si tu VPS la rota).
2. **Firewall del VPS** (GCP/Azure/AWS): abrir `80` y `443`:
   ```bash
   gcloud compute firewall-rules create allow-http --allow tcp:80,tcp:443
   ```
3. **Cambiar la contraseña del admin inicial**: la primera vez entra con
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
- **Actualizar**: `cd /opt/kardex-cloud-server && sudo git pull && sudo npm install --production && sudo systemctl restart kardex-cloud`
- **Backups**: se generan en `data/backups/` (copialos a otro disco de forma
  periódica; por ejemplo `cron` + `scp`).
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