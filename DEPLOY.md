# Despliegue en la nube — Inklusport

Guía paso a paso para publicar microservicios + frontend fuera de tu PC.

Hay **dos caminos**. Elige uno:

| Camino | Cuándo usarlo | Dificultad | Coste aproximado |
|--------|---------------|------------|------------------|
| **A — VPS + Docker** | Equipo pequeño, demo estable, control total | Baja | ~10–20 USD/mes |
| **B — Azure Container Apps** | Producción “cloud nativa”, escalado | Media | Variable (suele ser más caro) |

Requisitos comunes en ambos:

- Docker en la máquina desde la que construyes imágenes
- Repos clonados (orquestación + microservicios + frontend)
- Un `JWT_SECRET` **nuevo** (no el de desarrollo)
- Bases remotas (MySQL + Mongo) — en VPS puedes usar las del compose local si el disco es persistente

---

## Camino A — VPS (recomendado para empezar)

Un servidor Linux (DigitalOcean, Hetzner, Contabo, Azure VM, etc.) con **8 GB RAM** mínimo.

### A1. Crear el servidor

1. Crea un VPS Ubuntu 22.04+ con al menos **8 GB RAM** y **2 vCPU**.
2. Apunta un dominio (ej. `app.inklusport.uk`) al IP del VPS (registro A en Cloudflare/DNS).
3. Conéctate por SSH:

```bash
ssh root@TU_IP
```

### A2. Instalar Docker en el VPS

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# cierra sesión y vuelve a entrar
docker --version
docker compose version
```

### A3. Subir el código

En el VPS (o con `git clone` si los repos son privados y tienes acceso):

```bash
mkdir -p ~/inklusport && cd ~/inklusport
# Clona el repo de orquestación y cada microservicio como carpetas hermanas:
# ink-ms-auth, ink-ms-users, ink-ms-sports, ink-ms-accesibility,
# ink-ms-reports, ink-ms-suscriptions, ink-ms-gateway,
# ink-ms-ai-assistant, ink-ms-frontend
```

Estructura esperada:

```text
~/inklusport/
├── docker-compose.yml
├── .env
├── init-mysql/
├── ink-ms-auth/
├── ink-ms-users/
├── ...
└── ink-ms-frontend/
```

### A4. Configurar `.env`

```bash
cp .env.example .env
nano .env
```

Obligatorio:

- `JWT_SECRET` — genéralo en el VPS: `openssl rand -base64 64 | tr -d '\n'`
- `CLOUDFLARE_TOKEN` — solo si usas túnel; en VPS con dominio propio **no hace falta** (usas Caddy, paso A6)
- Si usas IA: `LLM_API_KEY` en `ink-ms-ai-assistant/.env`

### A5. Arrancar el stack (con bases en el propio VPS)

La forma más simple para el equipo: mismo compose que en local (incluye MySQL, Mongo y frontend).

```bash
cd ~/inklusport
# Imágenes ya publicadas en Docker Hub (DOCKERHUB_USER en .env):
docker compose pull
docker compose up -d
# Si aún no las has subido y tienes el código en el VPS:
#   docker compose -f docker-compose.dev.yml up -d --build
```

Comprueba:

```bash
docker compose ps
curl -s http://localhost:8088/ | head
curl -s http://localhost:8080/api/ai/health
```

- Frontend (nginx): puerto **8088**
- Gateway: puerto **8080**

### A6. HTTPS con Caddy (recomendado en VPS)

Instala Caddy y pon un reverse proxy al frontend (que ya proxea `/api` al gateway):

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install caddy
```

`/etc/caddy/Caddyfile`:

```caddy
app.inklusport.uk {
    reverse_proxy localhost:8088
}
```

```bash
sudo systemctl reload caddy
```

Abre en el navegador: `https://app.inklusport.uk/`

Postman: `https://app.inklusport.uk/api/...`

### A7. Firewall

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

No abras al público 3306, 27017 ni los puertos de microservicios (3001–3008).

### A8. Actualizar después de un cambio

```bash
cd ~/inklusport
# En tu PC, con el código actualizado:
#   .\push-images.ps1 -Service auth
#   .\push-images.ps1 -Service frontend
docker compose pull
docker compose up -d
```

---

## Camino B — Azure Container Apps

Usa `docker-compose.prod.yml`: **sin** MySQL/Mongo en contenedores; bases gestionadas + imágenes en ACR.

### B0. Herramientas en tu PC

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- Docker Desktop
- Cuenta Azure con suscripción activa

```bash
az login
az account set --subscription "NOMBRE_O_ID"
```

Sustituye en todos los comandos:

- `<region>` → p. ej. `eastus` o `mexicocentral`
- `<acr>` → nombre único del registry (solo minúsculas/números), p. ej. `inklusportacr`

### B1. Bases de datos gestionadas

**MySQL** (Azure Database for MySQL Flexible Server):

1. Crea el servidor (permite acceso desde Azure / firewall del entorno Container Apps).
2. Crea las bases:
   - `auth_ms`
   - `user_ms`
   - `sports_events_ms`
   - `analytics_ms`
   - `inklusport_subscriptions`
3. Ejecuta los scripts de `init-mysql/` **en orden** (01 → 07) contra ese servidor.

**MongoDB** (MongoDB Atlas o Cosmos DB API Mongo):

1. Crea cluster / cuenta.
2. Bases: `accessibility_notifications_db` e `inclusport_training_ia`.
3. Copia la connection string (`mongodb+srv://...`).

### B2. Variables de producción

```powershell
cd "C:\Users\Samu\Documents\Repos Aparte"
Copy-Item .env.prod.example .env.prod
# Edita .env.prod con REGISTRY, JWT_SECRET, URLs MySQL, Mongo, LLM_API_KEY
```

`REGISTRY` será `<acr>.azurecr.io` (lo creas en B3).

### B3. Grupo de recursos y registry

```bash
az group create --name inklusport-rg --location <region>
az acr create --resource-group inklusport-rg --name <acr> --sku Basic
az acr login --name <acr>
```

### B4. Construir y subir imágenes

Desde la carpeta de orquestación (hermanas = `ink-ms-*`):

```bash
# Windows PowerShell
$acr = "<acr>.azurecr.io"
$tag = "v1"

foreach ($s in @("auth","users","sports","accesibility","reports","suscriptions","gateway")) {
  docker build -t "$acr/ink-ms-$s:$tag" "./ink-ms-$s"
  docker push "$acr/ink-ms-$s:$tag"
}

docker build -t "$acr/ink-ms-ai-assistant:$tag" "./ink-ms-ai-assistant"
docker push "$acr/ink-ms-ai-assistant:$tag"
docker build -t "$acr/ink-mcp-inklusport:$tag" "./ink-mcp-inklusport"
docker push "$acr/ink-mcp-inklusport:$tag"

# Frontend (nginx + Angular)
docker build -t "$acr/ink-ms-frontend:$tag" "./ink-ms-frontend"
docker push "$acr/ink-ms-frontend:$tag"
```

Nota: en `docker-compose.prod.yml` el nombre de imagen de accessibility es `ink-ms-accessibility` (con doble c). Si el push usó la carpeta `ink-ms-accesibility`, etiqueta también:

```bash
docker tag "$acr/ink-ms-accesibility:$tag" "$acr/ink-ms-accessibility:$tag"
docker push "$acr/ink-ms-accessibility:$tag"
```

### B5. Entorno Container Apps

```bash
az containerapp env create \
  --name inklusport-env \
  --resource-group inklusport-rg \
  --location <region>
```

### B6. Desplegar desde el compose de producción

```bash
# Carga variables de .env.prod en la sesión (PowerShell)
Get-Content .env.prod | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
  $k,$v = $_.Split('=',2)
  Set-Item -Path "Env:$k" -Value $v
}

az containerapp compose create \
  --resource-group inklusport-rg \
  --environment inklusport-env \
  --compose-file-path docker-compose.prod.yml \
  --registry-server <acr>.azurecr.io
```

### B7. Ajustes obligatorios después del create

1. **Ingress**
   - `gateway-service`: externo (HTTPS)
   - Resto de microservicios: **interno**
2. **Réplicas mínimas** ≥ 1 en `gateway-service` y `auth-service` (arranque 30–55 s; scale-to-zero da timeouts).
3. **Frontend**: `docker-compose.prod.yml` hoy no incluye el frontend. Opciones:
   - Desplegar `ink-ms-frontend` como Container App aparte con ingress externo, proxy `/api` al FQDN interno del gateway, **o**
   - Servir el front en Static Web Apps / Blob + CDN apuntando `API_BASE_URL` al gateway público.
4. **Secretos**: mueve `JWT_SECRET`, contraseñas y `LLM_API_KEY` a secretos de Container Apps (no texto plano).

### B8. Probar

```bash
# URL del gateway (ajusta el nombre real que te dé Azure)
az containerapp show -g inklusport-rg -n gateway-service --query properties.configuration.ingress.fqdn -o tsv
```

- API: `https://<fqdn-gateway>/api/ai/health`
- App: URL del frontend cuando la hayas desplegado

### B9. Redeploy de un servicio

```bash
docker build -t <acr>.azurecr.io/ink-ms-auth:v2 ./ink-ms-auth
docker push <acr>.azurecr.io/ink-ms-auth:v2
az containerapp update -g inklusport-rg -n auth-service --image <acr>.azurecr.io/ink-ms-auth:v2
```

---

## Checklist final (ambos caminos)

- [ ] `JWT_SECRET` de producción (único y compartido por todos los servicios)
- [ ] Scripts `init-mysql/` aplicados (si las bases son externas)
- [ ] Mongo accesible desde los contenedores (IP allowlist / VNet)
- [ ] Gateway o frontend alcanzable por HTTPS
- [ ] `/api/ai/health` responde JSON
- [ ] Login desde el navegador funciona
- [ ] Secretos fuera de Git (`.env` / `.env.prod` en `.gitignore`)

---

## Qué NO hacer

- No uses `docker-compose.dev.yml` para publicar a internet (no incluye frontend).
- No abras MySQL/Mongo a `0.0.0.0/0` sin necesidad.
- No reutilices el `JWT_SECRET` de tu PC de desarrollo en producción.
- No dependas del Cloudflare Tunnel de tu laptop para “producción”: si apagas el PC, cae el servicio.

---

## Resumen de decisión

- **¿Queréis que el equipo entre ya sin factura Azure?** → Camino **A (VPS)**.
- **¿Queréis cloud gestionado y escalado?** → Camino **B (Azure)** + bases gestionadas + front aparte.

El túnel Cloudflare en tu PC sigue siendo válido solo como **demo temporal**.
