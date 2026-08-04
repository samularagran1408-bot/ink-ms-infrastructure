# Compila los seis microservicios Java. Sólo hace falta para ejecutarlos fuera de
# Docker: los Dockerfile son multi-stage y compilan por su cuenta.
Write-Host "Compilando los microservicios Java..." -ForegroundColor Cyan

$services = @(
    "ink-ms-auth",
    "ink-ms-users",
    "ink-ms-sports",
    "ink-ms-accesibility",
    "ink-ms-reports",
    "ink-ms-suscriptions",
    "ink-ms-gateway"
)

$failed = @()

foreach ($service in $services) {
    if (-not (Test-Path $service)) {
        Write-Host "`nOmitido ${service}: la carpeta no existe" -ForegroundColor Yellow
        $failed += $service
        continue
    }

    Write-Host "`nCompilando $service..." -ForegroundColor Yellow
    Push-Location $service
    mvn clean package -DskipTests
    if ($LASTEXITCODE -ne 0) { $failed += $service }
    Pop-Location
}

if ($failed.Count -gt 0) {
    Write-Host "`nFallaron: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "`nTodos los microservicios compilados." -ForegroundColor Green
