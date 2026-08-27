# Ejecuta la colección de Inklusport con Newman (CLI de Postman).
# Requisito: Node.js LTS y el stack levantado (gateway en :8080).

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Error "Necesitas Node.js (https://nodejs.org). Luego vuelve a ejecutar este script."
}

if (-not (Test-Path "node_modules\newman")) {
    Write-Host "Instalando Newman (solo la primera vez)..."
    npm install
}

Write-Host ""
Write-Host "=== Newman: Inklusport (entorno local) ==="
Write-Host "Gateway esperado: http://localhost:8080"
Write-Host ""

npm run test:html

if (Test-Path "newman-report.html") {
    Write-Host ""
    Write-Host "Informe HTML: $PSScriptRoot\newman-report.html"
    Start-Process "$PSScriptRoot\newman-report.html"
}
