# Construye las imágenes de los microservicios y las sube a Docker Hub.
# El compose principal (docker-compose.yml) ya no construye: solo descarga.
#
# Requisitos:
#   1. Cuenta en https://hub.docker.com/ (repositorios públicos).
#   2. DOCKERHUB_USER en .env, igual que tu usuario de Docker Hub.
#   3. Sesión iniciada:  docker login
#   4. Carpetas de código hermanas (ink-ms-auth, ink-ms-frontend, ...).
#
# Uso:
#   .\push-images.ps1
#   .\push-images.ps1 -Tag v1
#   .\push-images.ps1 -Service frontend   # solo una imagen

param(
    [string]$Tag = "",
    [string]$Service = ""
)

$ErrorActionPreference = "Stop"

function Read-DotEnvValue([string]$key) {
    $envFile = Join-Path $PSScriptRoot ".env"
    if (-not (Test-Path $envFile)) { return "" }
    foreach ($line in Get-Content $envFile) {
        if ($line -match "^\s*$key\s*=\s*(.*)$") {
            return $Matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return ""
}

$user = Read-DotEnvValue "DOCKERHUB_USER"
if (-not $user) { $user = $env:DOCKERHUB_USER }
if (-not $user) {
    Write-Host "Falta DOCKERHUB_USER. Ponlo en .env (tu usuario de Docker Hub)." -ForegroundColor Red
    exit 1
}

if (-not $Tag) { $Tag = Read-DotEnvValue "IMAGE_TAG" }
if (-not $Tag) { $Tag = "latest" }

$all = @(
    @{ Name = "auth";          Dir = "ink-ms-auth";           Image = "ink-ms-auth" }
    @{ Name = "users";         Dir = "ink-ms-users";          Image = "ink-ms-users" }
    @{ Name = "sports";        Dir = "ink-ms-sports";         Image = "ink-ms-sports" }
    @{ Name = "accessibility"; Dir = "ink-ms-accesibility";   Image = "ink-ms-accessibility" }
    @{ Name = "reports";       Dir = "ink-ms-reports";        Image = "ink-ms-reports" }
    @{ Name = "subscriptions"; Dir = "ink-ms-subscriptions";  Image = "ink-ms-subscriptions" }
    @{ Name = "mcp";           Dir = "ink-mcp-inklusport";    Image = "ink-mcp-inklusport" }
    @{ Name = "ai";            Dir = "ink-ms-ai-assistant";   Image = "ink-ms-ai-assistant" }
    @{ Name = "gateway";       Dir = "ink-ms-gateway";        Image = "ink-ms-gateway" }
    @{ Name = "frontend";      Dir = "ink-ms-frontend";       Image = "ink-ms-frontend" }
)

$targets = $all
if ($Service) {
    $targets = @($all | Where-Object { $_.Name -eq $Service -or $_.Image -eq $Service })
    if ($targets.Count -eq 0) {
        Write-Host "Servicio desconocido: $Service" -ForegroundColor Red
        Write-Host ("Valores: " + (($all | ForEach-Object { $_.Name }) -join ", "))
        exit 1
    }
}

Write-Host "Docker Hub user: $user" -ForegroundColor Cyan
Write-Host "Tag:             $Tag" -ForegroundColor Cyan
Write-Host ""

$failed = @()

foreach ($svc in $targets) {
    $context = Join-Path $PSScriptRoot $svc.Dir
    $full = "$user/$($svc.Image):$Tag"

    if (-not (Test-Path $context)) {
        Write-Host "Omitido $($svc.Image): no existe $context" -ForegroundColor Yellow
        $failed += $svc.Image
        continue
    }

    Write-Host "`n=== docker build $full ===" -ForegroundColor Yellow
    docker build -t $full $context
    if ($LASTEXITCODE -ne 0) {
        $failed += $svc.Image
        continue
    }

    Write-Host "=== docker push $full ===" -ForegroundColor Yellow
    docker push $full
    if ($LASTEXITCODE -ne 0) {
        $failed += $svc.Image
    }
}

if ($failed.Count -gt 0) {
    Write-Host "`nFallaron: $($failed -join ', ')" -ForegroundColor Red
    Write-Host "Si el push falla, ejecuta: docker login" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nImagenes publicadas. Arranque sin construir:" -ForegroundColor Green
Write-Host "  docker compose pull" -ForegroundColor Green
Write-Host "  docker compose up -d" -ForegroundColor Green
