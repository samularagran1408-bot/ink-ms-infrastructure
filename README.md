# ink-infra — Orquestación de Inklusport

Este repositorio contiene **sólo la orquestación**: los ficheros de Docker Compose,
los scripts de inicialización de las bases de datos y la documentación de
despliegue. El código de cada microservicio vive en su propio repositorio.

| Servicio | Repositorio | Puerto | Base de datos |
|----------|-------------|--------|---------------|
| Gateway | `ink-ms-gateway` | 8080 | — |
| Auth | `ink-ms-auth` | 3001 | MySQL `auth_ms` |
| Users | `ink-ms-users` | 3002 | MySQL `user_ms` |
| Sports | `ink-ms-sports` | 3003 | MySQL `sports_events_ms` |
| Accessibility | `ink-ms-accesibility` | 3004 | MongoDB |
| Reports | `ink-ms-reports` | 3006 | MySQL `analytics_ms` |
| Asistente IA | `ink-ms-ai-assistant` | 3008 | MongoDB |

Para trabajar hay que clonar los siete repositorios de microservicios como
carpetas hermanas de este fichero, porque el compose de desarrollo construye
desde esas rutas. El frontend vive en su propio repositorio y se clona aparte
cuando haga falta; no forma parte de este compose.

## Acceso público (Postman)

Con `CLOUDFLARE_TOKEN` definido, el contenedor `cloudflared` publica el gateway
en http://inklusport.inklusport.uk/. Las peticiones van a rutas `/api/...`
(por ejemplo `/api/auth/login`). En el túnel de Cloudflare Zero Trust el
hostname debe apuntar a `http://gateway-service:8080`.

## Arranque local

```bash
cp .env.example .env
# Rellena JWT_SECRET en .env; sin él los servicios no arrancan (ver más abajo).
docker compose up -d --build
```

El gateway queda en http://localhost:8080. Los servicios también publican sus
puertos individuales para poder depurarlos directamente.

Los Dockerfile son multi-stage: compilan con Maven dentro de la imagen, así que no
hace falta ejecutar `mvn` antes. `build-all.ps1` sólo es útil si quieres los JAR
para ejecutarlos fuera de Docker.

## Configuración por variables de entorno

Ningún secreto está escrito en el código. Dos variables **no tienen valor por
defecto** y el servicio se niega a arrancar si faltan, en lugar de arrancar con un
valor conocido:

- `JWT_SECRET` — lo usan todos los servicios. Uno firma los tokens y los demás los
  validan, así que debe ser idéntico en todos. Genéralo con
  `openssl rand -base64 64` (o el equivalente de PowerShell que está en
  `.env.example`).
- `MONGODB_URI` — lleva usuario y contraseña dentro.

El resto (`MYSQL_URL`, `LOG_LEVEL`, `SHOW_SQL`, `JPA_DDL_AUTO`, las URL entre
servicios y la configuración de correo) tiene valores por defecto pensados para el
compose local y se sobrescriben en el despliegue remoto.

## Despliegue remoto

`docker-compose.prod.yml` es el fichero de despliegue. Se diferencia del local en
tres cosas, cada una por un motivo concreto:

- **No incluye MySQL ni MongoDB.** En una plataforma de contenedores gestionada el
  disco del contenedor es efímero, así que los datos se perderían en cada
  reinicio. Las bases van fuera, como servicio gestionado.
- **No construye imágenes, las descarga de un registry.** En Container Apps, ECS o
  Cloud Run no hay ninguna máquina donde compilar.
- **Sólo el gateway publica puerto.** El resto se comunica por la red interna, de
  forma que ni las bases ni los servicios internos quedan accesibles desde fuera.

### Antes de empezar

1. Aplica los scripts de `init-mysql/` contra la instancia gestionada de MySQL.
   Sólo se ejecutan automáticamente en el contenedor local, no en la base remota.
   Ojo: cada servicio usa su propio esquema, así que hay que crear las cuatro
   bases (`auth_ms`, `user_ms`, `sports_events_ms`, `analytics_ms`).
2. Genera un `JWT_SECRET` **nuevo**, distinto del de desarrollo.
3. Copia `.env.example` a `.env.prod` y rellena las URL de las bases gestionadas,
   las credenciales y `LLM_API_KEY`.

### Azure Container Apps

Es la opción que mejor encaja con este proyecto: tiene DNS interno automático
dentro de un mismo entorno, así que las URL `http://auth-service:3001` que ya usa
el gateway siguen funcionando sin reescribirse.

```bash
# 1. Grupo de recursos y registry
az group create --name inklusport-rg --location <region>
az acr create --resource-group inklusport-rg --name <acr> --sku Basic
az acr login --name <acr>

# 2. Construir y subir las siete imágenes
for s in auth users sports accesibility reports gateway; do
  docker build -t <acr>.azurecr.io/ink-ms-$s:v1 ../ink-ms-$s
  docker push <acr>.azurecr.io/ink-ms-$s:v1
done
docker build -t <acr>.azurecr.io/ink-ms-ai-assistant:v1 ../ink-ms-ai-assistant
docker push <acr>.azurecr.io/ink-ms-ai-assistant:v1

# 3. Entorno de Container Apps
az containerapp env create --name inklusport-env \
  --resource-group inklusport-rg --location <region>

# 4. Desplegar desde el compose de producción
az containerapp compose create \
  --resource-group inklusport-rg \
  --environment inklusport-env \
  --compose-file-path docker-compose.prod.yml \
  --registry-server <acr>.azurecr.io
```

Después del despliegue quedan dos ajustes que el compose no puede expresar:

- Dejar el ingress de `gateway-service` en **externo** y el de los otros seis en
  **interno**. Así sólo el gateway es accesible desde internet.
- Poner `minReplicas: 1` al menos en `gateway-service` y `auth-service`. Estas
  aplicaciones tardan entre 30 y 55 segundos en arrancar (medido), así que con
  escalado a cero la primera petición tras un rato de inactividad daría timeout.

Los secretos (`JWT_SECRET`, contraseñas de las bases, `LLM_API_KEY`) conviene
guardarlos como secretos de Container Apps y referenciarlos, en lugar de dejarlos
como variables de entorno en texto plano.

### En un servidor propio

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d
```

Hace falta además un reverse proxy delante del gateway para tener HTTPS; Caddy es
el más simple porque gestiona el certificado automáticamente. Cuenta con 8 GB de
memoria: son seis JVM más el servicio de Python.
