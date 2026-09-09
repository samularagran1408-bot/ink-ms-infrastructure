# Aplica réplicas para mucha gente a la vez.
# No lo uses en docker-compose.yml / docker-compose.dev.yml (MySQL en el mismo host).
#
# Azure (después de DEPLOY.md camino B):
#   .\scale-prod.ps1
#   .\scale-prod.ps1 -ResourceGroup inklusport-rg -HotMin 2 -HotMax 6
#
# VPS (compose de producción, bases ya fuera):
#   .\scale-prod.ps1 -Vps

param(
    [string]$ResourceGroup = "inklusport-rg",
    [int]$HotMin = 2,
    [int]$HotMax = 6,
    [switch]$Vps
)

$ErrorActionPreference = "Stop"

$hot = @("gateway-service", "auth-service", "sports-service", "users-service")
$warm = @("reports-service", "accessibility-service", "subscriptions-service")
$cold = @("ai-service", "mcp-service")

if ($Vps) {
    Write-Host "VPS: 2 réplicas de auth/sports/users. Gateway se queda en 1 (puerto 8080)."
    docker compose -f docker-compose.prod.yml --env-file .env.prod up -d `
        --scale auth-service=2 `
        --scale sports-service=2 `
        --scale users-service=2 `
        --scale gateway-service=1
    docker compose -f docker-compose.prod.yml --env-file .env.prod ps
    return
}

function Set-AppScale([string]$Name, [int]$Min, [int]$Max) {
    Write-Host "Réplicas $Name → min=$Min max=$Max"
    az containerapp update `
        --resource-group $ResourceGroup `
        --name $Name `
        --min-replicas $Min `
        --max-replicas $Max
}

Write-Host "Azure Container Apps en grupo $ResourceGroup"
foreach ($name in $hot) { Set-AppScale $name $HotMin $HotMax }
foreach ($name in $warm) { Set-AppScale $name 1 ([Math]::Max(3, $HotMin)) }
foreach ($name in $cold) { Set-AppScale $name 1 2 }

Write-Host "Listo. Ingress del gateway debe ser externo; el resto interno."
Write-Host "Comprueba max_connections de MySQL >= réplicas × HIKARI_MAX_POOL (por defecto 10) × servicios Java con MySQL."
