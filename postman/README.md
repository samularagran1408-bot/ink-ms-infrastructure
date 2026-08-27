# Postman + Newman sobre Inklusport

Guía de la exposición: definiciones, instalación para compañeros y comandos de Newman.

```
Postman / Newman  →  http://localhost:8080  (ink-ms-gateway)
                         │
         ├── /api/auth/**              ink-ms-auth           :3001
         ├── /api/users/**             ink-ms-users          :3002
         ├── /api/events|sports|...    ink-ms-sports         :3003
         ├── /api/preferences|...      ink-ms-accesibility   :3004
         ├── /api/plans|subscriptions  ink-ms-suscriptions   :3005
         ├── /api/dashboard|analytics  ink-ms-reports        :3006
         └── /api/ai/**                ink-ms-ai-assistant   :3008
```

Cada carpeta de la colección es un microservicio. Newman puede ejecutar **una sola** con `--folder`.

---

## 1. Definiciones

**API REST.** Interfaz HTTP para que un cliente (app, Postman, Newman) hable con el servidor usando métodos (`GET`, `POST`, `PUT`, `DELETE`) y rutas (`/api/events`). Inklusport expone su API a través del **gateway** en el puerto `8080`.

**API Gateway.** Puerta única. Postman y Newman **no** llaman a `:3001` o `:3003`: llaman a `http://localhost:8080/api/...` y el gateway reparte al microservicio correcto.

**JWT (JSON Web Token).** Token que devuelve el login. Las peticiones protegidas lo envían así: `Authorization: Bearer <token>`.

**Postman.** Aplicación de escritorio para diseñar, enviar y probar peticiones HTTP. Sirve para explorar el API a mano: método, URL, headers, body JSON, tests y entornos.

**Colección.** Archivo JSON con carpetas de peticiones (`Inklusport.postman_collection.json`). Es el “suite” de pruebas. Se abre en Postman y Newman ejecuta el mismo archivo.

**Environment (entorno).** Archivo JSON con variables (`{{baseUrl}}`, `{{email}}`, `{{password}}`, `{{token}}`). Permite cambiar local ↔ público sin reescribir URLs.

**Tests (scripts).** Código JavaScript en cada petición (pestaña Tests). Afirman cosas como “el status es 200” o “hay un JWT”, y pueden **guardar variables** (el login guarda `{{token}}`).

**Newman.** Runner en **línea de comandos** de Postman. Lee la misma colección y los mismos tests, sin abrir la ventana. Sirve para CI, scripts y demos en terminal. No sustituye a Postman: es Postman sin GUI.

**Assertion.** Cada `pm.test(...)`. Newman cuenta cuántas pasaron y cuántas fallaron. Si falla alguna, el código de salida es distinto de `0` (un pipeline de CI quedaría en rojo).

**Reporter.** Formato de salida: `cli` (terminal), `htmlextra` (informe HTML), `json` (artefacto para máquinas).

**`--folder`.** Ejecuta solo una carpeta de la colección (un microservicio).

**`--bail`.** Se detiene en el primer fallo, como un job de CI.

---

## 2. Qué tienen que descargar los compañeros (instalación)

Hace falta **tres cosas**: Postman (GUI), Node.js (para Newman) y esta carpeta `postman/`.

### 2.1 Postman (obligatorio para la parte visual)

1. Entra a [https://www.postman.com/downloads/](https://www.postman.com/downloads/).
2. Descarga **Postman Desktop** (Windows).
3. Instálalo y ábrelo. Se puede usar **sin cuenta** (Skip / continuar como invitado) para importar colecciones.

**Importar el ejemplo de Inklusport**

1. En Postman: **Import**.
2. Elige estos dos archivos (están en esta carpeta):
   - `Inklusport.postman_collection.json`
   - `Inklusport.local.postman_environment.json`
3. Arriba a la derecha, selecciona el entorno **Inklusport Local (gateway)**.
4. En el entorno, cambia `email` y `password` por un usuario que exista en la base (no dejes el placeholder).
5. Orden recomendado: **POST login** → **GET perfil** → **GET eventos**.

### 2.2 Node.js (obligatorio para Newman)

Newman es un programa de Node. Sin Node no corre la terminal.

1. Entra a [https://nodejs.org](https://nodejs.org).
2. Descarga la versión **LTS**.
3. Instala con las opciones por defecto (marca “Add to PATH”).
4. **Cierra y vuelve a abrir** la terminal (PowerShell o la de Cursor).
5. Comprueba:

```powershell
node -v
npm -v
```

Deben salir números de versión. Si `npm` no se reconoce, Node no quedó en el PATH: reinstala o abre una terminal nueva.

### 2.3 Newman (en esta carpeta, no hace falta instalarlo global)

En PowerShell:

```powershell
cd "c:\Users\Samu\Documents\Repos Aparte\postman"
npm install
```

Eso instala `newman` y el reporter HTML (`newman-reporter-htmlextra`) usando el `package.json` de esta carpeta. **No hace falta** `npm install -g newman`.

Comprobación:

```powershell
npx newman --version
```

### 2.4 API de Inklusport (para que las peticiones respondan)

Newman dispara HTTP contra el gateway. Si nadie está escuchando en `:8080`, todo falla por conexión.

**Opción A — Local (la de la expo)**

En la raíz del repo de orquestación (un nivel arriba de `postman/`):

```powershell
cd "c:\Users\Samu\Documents\Repos Aparte"
docker compose up -d
```

Hace falta [Docker Desktop](https://www.docker.com/products/docker-desktop/). El gateway queda en `http://localhost:8080`.

Comprueba:

```powershell
npx newman run Inklusport.postman_collection.json -e Inklusport.local.postman_environment.json --folder "00 — Salud gateway"
```

(Ese comando se lanza **desde** `postman/`.)

**Opción B — Entorno público**

Si el túnel Cloudflare está arriba, usa `Inklusport.publico.postman_environment.json` (`baseUrl` = `https://inklusport.inklusport.uk`). Ver `npm run test:publico` más abajo.

### 2.5 Resumen de descargas

| Qué | Para qué | Dónde |
|---|---|---|
| Postman Desktop | Ver y enviar peticiones a mano | [postman.com/downloads](https://www.postman.com/downloads/) |
| Node.js LTS | Poder ejecutar Newman | [nodejs.org](https://nodejs.org) |
| Esta carpeta `postman/` | Colección, entornos y `npm install` | El repo del proyecto |
| Docker Desktop | Levantar Inklusport en local | [docker.com](https://www.docker.com/products/docker-desktop/) (solo si van a pegarle a `localhost`) |

No hace falta cuenta de Postman Enterprise ni instalar Newman global.

---

## 3. Cómo usar Postman (GUI)

1. Importa colección + entorno local (paso 2.1).
2. Selecciona **Inklusport Local (gateway)**.
3. Ejecuta en orden:
   - GET salud IA
   - POST login (el test guarda `{{token}}`)
   - GET perfil / eventos / rutinas
   - POST chat del agente
4. Opcional: botón **Run collection** (play) para mandar toda la carpeta de una vez.

---

## 4. Comandos de Newman (qué significa cada uno)

Todos se ejecutan **dentro de** `postman/`:

```powershell
cd "c:\Users\Samu\Documents\Repos Aparte\postman"
```

### 4.1 Piezas que se repiten

| Pieza | Significado |
|---|---|
| `npx newman` | Ejecuta Newman sin instalarlo global (usa el de `node_modules`) |
| `run` | Corre una colección |
| `Inklusport.postman_collection.json` | Las peticiones + tests |
| `-e Inklusport.local.postman_environment.json` | Sustituye `{{baseUrl}}`, `{{email}}`, `{{password}}` |
| `--folder "03 — Sports"` | Solo esa carpeta (ese microservicio) |
| `--delay-request 300` | Espera 300 ms entre peticiones (el login termina de guardar el token) |
| `--bail` | Para en el primer test fallido |
| `--verbose` | Imprime headers y body (útil para ver un 400/401) |
| `--iteration-count 3` | Repite el run 3 veces |
| `--timeout-request 180000` | Timeout por petición en milisegundos (el chat de IA puede tardar) |
| `-r cli,htmlextra` | Salida en terminal **y** informe HTML |
| `-r cli,json` | Terminal + JSON para CI |
| `$LASTEXITCODE` | En PowerShell: `0` si todo pasó; distinto de `0` si hubo fallos |

### 4.2 Orden recomendado para la expo (~4 min)

**1. Entrar a la carpeta**

```powershell
cd "c:\Users\Samu\Documents\Repos Aparte\postman"
```

Significa: el directorio de trabajo es donde están la colección y Newman.

**2. Smoke del gateway**

```powershell
npx newman run Inklusport.postman_collection.json -e Inklusport.local.postman_environment.json --folder "00 — Salud gateway"
```

Significa: solo health + diagnóstico de la IA. Comprueba que el gateway y `ink-ms-ai-assistant` responden.

**3. Sports (sin login, el más limpio)**

```powershell
npx newman run Inklusport.postman_collection.json -e Inklusport.local.postman_environment.json --folder "03 — Sports"
```

Significa: lista eventos, calendario, deportes y rutinas. Demuestra un microservicio concreto (`ink-ms-sports`) entrando por el gateway.

**4. Auth + Users (JWT)**

```powershell
npx newman run Inklusport.postman_collection.json -e Inklusport.local.postman_environment.json --folder "01 — Auth" --folder "02 — Users"
```

Significa: login (guarda `{{token}}`), valida el JWT y pide el perfil. Dos carpetas en un solo run.

**5. Informe HTML (cierre visual)**

```powershell
npx newman run Inklusport.postman_collection.json -e Inklusport.local.postman_environment.json --delay-request 300 -r cli,htmlextra --reporter-htmlextra-export newman-report.html --reporter-htmlextra-title "Inklusport CI"
Start-Process .\newman-report.html
```

Significa: corre la colección (con pausa entre requests), genera `newman-report.html` y lo abre en el navegador. Es el artefacto “humano” de la prueba.

Atajo equivalente:

```powershell
.\run-newman.ps1
```

o:

```powershell
npm run test:html
```

### 4.3 Comandos extra (si preguntan o sobra tiempo)

**Varios servicios a la vez (parece un job de CI)**

```powershell
npx newman run Inklusport.postman_collection.json -e Inklusport.local.postman_environment.json --delay-request 300 --folder "00 — Salud gateway" --folder "03 — Sports" --folder "05 — Subscriptions"
```

Significa: smoke de gateway + sports + planes/suscripciones, con 300 ms entre llamadas.

**Parar al primer fallo**

```powershell
npx newman run Inklusport.postman_collection.json -e Inklusport.local.postman_environment.json --bail
```

Significa: si el login o cualquier test falla, Newman no sigue. Así trabaja un pipeline.

**Ver el cuerpo del error**

```powershell
npx newman run Inklusport.postman_collection.json -e Inklusport.local.postman_environment.json --folder "01 — Auth" --verbose
```

Significa: imprime request/response. Sirve para enseñar un 400 o un JWT en claro (con cuidado).

**JSON para CI + código de salida**

```powershell
npx newman run Inklusport.postman_collection.json -e Inklusport.local.postman_environment.json -r cli,json --reporter-json-export newman-result.json
echo "Exit code: $LASTEXITCODE"
```

Significa: además de la terminal, escribe `newman-result.json`. `$LASTEXITCODE` distinto de `0` = hubo assertions failed (GitHub Actions pondría el job en rojo).

**Repetir el smoke 3 veces**

```powershell
npx newman run Inklusport.postman_collection.json -e Inklusport.local.postman_environment.json --folder "00 — Salud gateway" --iteration-count 3
```

Significa: la misma carpeta tres veces (regresión corta). Newman no es una herramienta de carga; para eso existiría k6.

**Colección completa sin HTML**

```powershell
npx newman run Inklusport.postman_collection.json -e Inklusport.local.postman_environment.json --delay-request 300
```

o:

```powershell
npm run test
```

**Entorno público (túnel Cloudflare)**

```powershell
npm run test:publico
```

Significa: misma colección, `baseUrl` = `https://inklusport.inklusport.uk`.

### 4.4 Un microservicio por comando (`npm run`)

Estos scripts están en `package.json`. Hacen lo mismo que `npx newman run ... --folder`.

```powershell
npm run test:salud      # IA health + diagnóstico
npm run test:auth       # login + validate + login inválido
npm run test:users      # auth + perfil (el login va primero para el token)
npm run test:sports     # eventos, deportes, rutinas (casi no necesita login)
npm run test:access     # auth + preferencias / notificaciones / voz
npm run test:subs       # planes (público) + mi suscripción
npm run test:reports    # auth + dashboard analítico
npm run test:ia         # auth + chat (timeout 180 s; ir al final)
```

Un **403** en Reports o Subscriptions puede seguir siendo test **verde**: el gateway sí llegó al microservicio; el rol no alcanza. Un **500** es un fallo real del servicio (Newman lo marca en rojo si el test esperaba 200).

---

## 5. Variables del entorno

| Variable | Uso |
|---|---|
| `baseUrl` | Gateway local (`http://localhost:8080`) o dominio público |
| `email` / `password` | Login. Pon un usuario real; no subas la contraseña al git |
| `token` | JWT; lo rellena el test del login |
| `userId` | Lo rellena el GET perfil |
| `conversacion_id` | Lo rellena el chat si el agente lo envía |

El valor `Demo1234!` de la colección es un **placeholder**. Sin un usuario real, el login da 400 y el resto autenticado falla (Newman lo muestra: eso también es una demo válida de tests).
