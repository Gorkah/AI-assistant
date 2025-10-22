# NEXO Soluciones IA - Script de Validación del Sistema
# Versión: 1.0.0
# Propósito: Validar que todos los componentes estén correctamente configurados

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "       VALIDACIÓN DEL SISTEMA NEXO IA         " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$global:totalTests = 0
$global:passedTests = 0
$global:failedTests = 0
$global:warnings = 0

# Función para registrar resultados
function Test-Component {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$ErrorMessage = "Error en la prueba"
    )
    
    $global:totalTests++
    Write-Host -NoNewline "🔍 Testing: $TestName... "
    
    try {
        $result = & $TestScript
        if ($result) {
            Write-Host "✅ PASS" -ForegroundColor Green
            $global:passedTests++
            return $true
        } else {
            Write-Host "❌ FAIL - $ErrorMessage" -ForegroundColor Red
            $global:failedTests++
            return $false
        }
    }
    catch {
        Write-Host "❌ ERROR - $_" -ForegroundColor Red
        $global:failedTests++
        return $false
    }
}

# 1. VALIDACIÓN DE ESTRUCTURA DE ARCHIVOS
Write-Host "1️⃣ VALIDACIÓN DE ESTRUCTURA DE ARCHIVOS" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

$requiredFiles = @{
    "Pack Estándar" = @(
        "Recepcionista\Agente_recepcionista_NEXO.json",
        "Recepcionista\Agente_Atencion_Gmail.json",
        "LEADS\Captacion_Leads_Formulario.json"
    )
    "Pack Premium" = @(
        "Recepcionista\Agente_Voice_WhatsApp.json",
        "ICEBREAKER\Email_Icebreaker_Personalizado.json",
        "FACTURAS\Automatiza facturas.json"
    )
    "Pack NEXA" = @(
        "PERSONAL ASSISTANT\Telegram_asistant.json",
        "PERSONAL ASSISTANT\Personal_Assistant_whatsapp.json",
        "VIDEOS VEO 3\VEO_3_VIDEOS.json",
        "ANALYTICS\Agente_Analisis_Empresarial.json"
    )
}

foreach ($pack in $requiredFiles.Keys) {
    Write-Host "  📦 $pack" -ForegroundColor Cyan
    foreach ($file in $requiredFiles[$pack]) {
        Test-Component -TestName $file -TestScript {
            Test-Path (Join-Path $PSScriptRoot "..\$file")
        } -ErrorMessage "Archivo no encontrado"
    }
    Write-Host ""
}

# 2. VALIDACIÓN DE CONFIGURACIÓN
Write-Host "2️⃣ VALIDACIÓN DE CONFIGURACIÓN" -ForegroundColor Yellow
Write-Host "===============================" -ForegroundColor Yellow
Write-Host ""

Test-Component -TestName "config\setup_config.json" -TestScript {
    $configPath = Join-Path $PSScriptRoot "..\config\setup_config.json"
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            return $config.version -eq "1.0.0"
        } catch {
            return $false
        }
    }
    return $false
} -ErrorMessage "Archivo de configuración inválido o no encontrado"

Test-Component -TestName "README.md" -TestScript {
    Test-Path (Join-Path $PSScriptRoot "..\README.md")
} -ErrorMessage "Documentación no encontrada"

# 3. VALIDACIÓN DE CREDENCIALES
Write-Host ""
Write-Host "3️⃣ VALIDACIÓN DE CREDENCIALES" -ForegroundColor Yellow
Write-Host "=============================" -ForegroundColor Yellow
Write-Host ""

$envFile = Join-Path $PSScriptRoot "..\.env"
if (Test-Path $envFile) {
    Write-Host "✅ Archivo .env encontrado" -ForegroundColor Green
    
    # Leer variables de entorno
    $envContent = Get-Content $envFile
    $requiredVars = @("OPENAI_API_KEY", "EVOLUTION_API_URL", "AIRTABLE_PAT")
    
    foreach ($var in $requiredVars) {
        if ($envContent -match "$var=") {
            Write-Host "  ✅ $var configurada" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  $var no configurada" -ForegroundColor Yellow
            $global:warnings++
        }
    }
} else {
    Write-Host "⚠️  Archivo .env no encontrado" -ForegroundColor Yellow
    Write-Host "   Ejecuta el script setup.ps1 para configurar credenciales" -ForegroundColor Gray
    $global:warnings++
}

# 4. VALIDACIÓN DE WORKFLOWS JSON
Write-Host ""
Write-Host "4️⃣ VALIDACIÓN DE WORKFLOWS JSON" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Yellow
Write-Host ""

$allWorkflows = Get-ChildItem -Path (Join-Path $PSScriptRoot "..") -Filter "*.json" -Recurse | 
                Where-Object { $_.FullName -notmatch "node_modules|config" }

foreach ($workflow in $allWorkflows) {
    Test-Component -TestName $workflow.Name -TestScript {
        try {
            $content = Get-Content $workflow.FullName -Raw | ConvertFrom-Json
            # Verificar que tenga estructura básica de n8n
            return ($content.nodes -and $content.connections)
        } catch {
            return $false
        }
    } -ErrorMessage "JSON inválido o estructura incorrecta"
}

# 5. VERIFICACIÓN DE DEPENDENCIAS
Write-Host ""
Write-Host "5️⃣ VERIFICACIÓN DE DEPENDENCIAS" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Yellow
Write-Host ""

Test-Component -TestName "Node.js" -TestScript {
    try {
        $version = node --version
        return $version -match "v\d+\.\d+\.\d+"
    } catch {
        return $false
    }
} -ErrorMessage "Node.js no instalado"

Test-Component -TestName "NPM" -TestScript {
    try {
        $version = npm --version
        return $version -match "\d+\.\d+\.\d+"
    } catch {
        return $false
    }
} -ErrorMessage "NPM no instalado"

Test-Component -TestName "n8n (global)" -TestScript {
    try {
        $n8nCheck = npm list -g n8n --depth=0 2>$null
        return $n8nCheck -match "n8n@"
    } catch {
        return $false
    }
} -ErrorMessage "n8n no instalado globalmente"

# 6. VERIFICACIÓN DE CONECTIVIDAD
Write-Host ""
Write-Host "6️⃣ VERIFICACIÓN DE CONECTIVIDAD" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Yellow
Write-Host ""

Test-Component -TestName "Conexión a Internet" -TestScript {
    try {
        $response = Invoke-WebRequest -Uri "https://www.google.com" -UseBasicParsing -TimeoutSec 5
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
} -ErrorMessage "Sin conexión a Internet"

Test-Component -TestName "OpenAI API (endpoint)" -TestScript {
    try {
        $response = Invoke-WebRequest -Uri "https://api.openai.com/v1/models" -Method Head -TimeoutSec 5 -ErrorAction SilentlyContinue
        return $true
    } catch {
        # El endpoint responde aunque no tengamos API key válida
        return $_.Exception.Response.StatusCode -eq 401
    }
} -ErrorMessage "No se puede alcanzar OpenAI API"

# RESUMEN FINAL
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "              RESUMEN DE VALIDACIÓN            " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$successRate = if ($global:totalTests -gt 0) { 
    [math]::Round(($global:passedTests / $global:totalTests) * 100, 2) 
} else { 0 }

Write-Host "📊 Resultados:" -ForegroundColor White
Write-Host "   Total de pruebas: $global:totalTests" -ForegroundColor White
Write-Host "   ✅ Exitosas: $global:passedTests" -ForegroundColor Green
Write-Host "   ❌ Fallidas: $global:failedTests" -ForegroundColor Red
Write-Host "   ⚠️  Advertencias: $global:warnings" -ForegroundColor Yellow
Write-Host "   📈 Tasa de éxito: $successRate%" -ForegroundColor Cyan
Write-Host ""

# Estado general
if ($global:failedTests -eq 0 -and $global:warnings -eq 0) {
    Write-Host "✅ SISTEMA COMPLETAMENTE OPERATIVO" -ForegroundColor Green -BackgroundColor DarkGreen
    Write-Host "   El sistema está listo para usar" -ForegroundColor Green
} elseif ($global:failedTests -eq 0) {
    Write-Host "⚠️  SISTEMA OPERATIVO CON ADVERTENCIAS" -ForegroundColor Yellow -BackgroundColor DarkYellow
    Write-Host "   Revisa las advertencias antes de continuar" -ForegroundColor Yellow
} elseif ($global:failedTests -le 3) {
    Write-Host "⚠️  SISTEMA PARCIALMENTE OPERATIVO" -ForegroundColor Yellow -BackgroundColor DarkYellow
    Write-Host "   Algunos componentes necesitan atención" -ForegroundColor Yellow
} else {
    Write-Host "❌ SISTEMA NO OPERATIVO" -ForegroundColor Red -BackgroundColor DarkRed
    Write-Host "   Se requiere configuración adicional" -ForegroundColor Red
}

Write-Host ""
Write-Host "📝 Recomendaciones:" -ForegroundColor Cyan

if ($global:warnings -gt 0 -or $global:failedTests -gt 0) {
    if (-not (Test-Path $envFile)) {
        Write-Host "   1. Ejecuta .\setup.ps1 para configurar credenciales" -ForegroundColor White
    }
    if ($global:failedTests -gt 0) {
        Write-Host "   2. Revisa los archivos faltantes o corruptos" -ForegroundColor White
        Write-Host "   3. Verifica la instalación de dependencias" -ForegroundColor White
    }
    if ($global:warnings -gt 0) {
        Write-Host "   4. Completa la configuración de credenciales API" -ForegroundColor White
    }
} else {
    Write-Host "   ✅ No se requieren acciones adicionales" -ForegroundColor Green
    Write-Host "   🚀 Puedes comenzar a importar los workflows en n8n" -ForegroundColor Green
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Validación completada: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Generar reporte de validación
$reportPath = Join-Path $PSScriptRoot "..\validation_report.txt"
$report = @"
NEXO SOLUCIONES IA - REPORTE DE VALIDACIÓN
==========================================
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')

RESUMEN:
- Total de pruebas: $global:totalTests
- Exitosas: $global:passedTests
- Fallidas: $global:failedTests
- Advertencias: $global:warnings
- Tasa de éxito: $successRate%

ESTADO: $(if ($global:failedTests -eq 0 -and $global:warnings -eq 0) { "COMPLETAMENTE OPERATIVO" } 
         elseif ($global:failedTests -eq 0) { "OPERATIVO CON ADVERTENCIAS" }
         elseif ($global:failedTests -le 3) { "PARCIALMENTE OPERATIVO" }
         else { "NO OPERATIVO" })

Generado automáticamente por validate_system.ps1
"@

Set-Content -Path $reportPath -Value $report
Write-Host "📄 Reporte guardado en: validation_report.txt" -ForegroundColor Gray
