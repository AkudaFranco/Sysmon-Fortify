<#
.SYNOPSIS
    Instalador automatizado de Sysmon con configuración de SwiftOnSecurity optimizada + Reinicio de Agente Wazuh para consolidar nueva monitorización.
    v0.3 > Robustez + Autocuración + Validación de errores + Limpieza de manifiestos
    Autor: Cristian Franco @ Akuda Cybersecurity
#>

$ErrorActionPreference = "Stop"

# 0. CONFIGURACIÓN DE CODIFICACIÓN (Para evitar caracteres raros)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. VERIFICACIÓN DE PERMISOS DE ADMINISTRADOR
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning " [!] ESTE SCRIPT NECESITA PERMISOS DE ADMINISTRADOR."
    Write-Warning "     Por favor, cierra esta ventana, haz click derecho en PowerShell y selecciona 'Ejecutar como administrador'."
    Break
}

# Configuración de rutas
$WorkDir = "C:\Sysmon_Install"
if (-not (Test-Path -Path $WorkDir)) {
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
}
Set-Location $WorkDir

Write-Host "[*] Iniciando despliegue de Sysmon para Endpoint Critico..." -ForegroundColor Cyan

# 2. Descargar Binarios y Configuración
Write-Host "[-] Descargando binarios y configuracion..."
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    # Sysmon
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "$WorkDir\Sysmon.zip"
    Expand-Archive -Path "$WorkDir\Sysmon.zip" -DestinationPath "$WorkDir" -Force
    # Configuración SwiftOnSecurity
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "$WorkDir\sysmonconfig.xml"
}
catch {
    Write-Host "[X] Error de descarga. Verifica conexión a internet." -ForegroundColor Red
    Break
}

# 3. FUNCION DE INSTALACIÓN ROBUSTA DE SYSMON
function Install-SysmonProcess {
    param ([string]$Arguments)
    
    # Usamos Start-Process para capturar el código de salida real
    $Process = Start-Process -FilePath "$WorkDir\Sysmon64.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    return $Process.ExitCode
}

# 4. EJECUCIÓN DE LA INSTALACIÓN
Write-Host "[-] Instalando servicio Sysmon..." -ForegroundColor Yellow

# Intentar instalación estándar (con flag -n para red)
$ExitCode = Install-SysmonProcess -Arguments "-i `"$WorkDir\sysmonconfig.xml`" -accepteula -l -n"

if ($ExitCode -eq 0) {
    Write-Host "[+] Sysmon instalado correctamente (Exit Code 0)." -ForegroundColor Green
}
else {
    Write-Host "[!] Fallo en la instalacion inicial (Exit Code: $ExitCode)." -ForegroundColor Red
    Write-Host "    Intentando limpieza de manifiestos corruptos (Force Uninstall)..." -ForegroundColor Yellow
    
    # Intento de autocuración: Desinstalar primero para limpiar wevtutil/manifests
    $Null = Install-SysmonProcess -Arguments "-u force"
    Start-Sleep -Seconds 2
    
    Write-Host "[-] Reintentando instalacion..." -ForegroundColor Yellow
    $RetryCode = Install-SysmonProcess -Arguments "-i `"$WorkDir\sysmonconfig.xml`" -accepteula -l -n"
    
    if ($RetryCode -eq 0) {
        Write-Host "[+] Recuperacion exitosa. Sysmon instalado." -ForegroundColor Green
    }
    else {
        Write-Host "[X] ERROR FATAL: No se pudo instalar Sysmon tras el reintento." -ForegroundColor Red
        Write-Host "    Por favor, ejecuta 'Sysmon64.exe -u' manualmente y reinicia."
        Break
    }
}

# 5. Verificación de Servicio
Write-Host "[-] Verificando estado del servicio..."
Start-Sleep -Seconds 3 # Dar tiempo a Windows para registrar el servicio
$SysmonStatus = Get-Service Sysmon64 -ErrorAction SilentlyContinue

if ($SysmonStatus -and $SysmonStatus.Status -eq 'Running') {
    Write-Host "[V] CHECK: El servicio Sysmon esta corriendo." -ForegroundColor Green
}
else {
    Write-Host "[X] ERROR: El servicio Sysmon NO esta corriendo." -ForegroundColor Red
    Write-Host "    Estado actual: $(if($SysmonStatus){$SysmonStatus.Status}else{'No encontrado'})"
    Break
}

# 6. REINICIO DEL AGENTE WAZUH
Write-Host "[-] Reiniciando Agente Wazuh para aplicar cambios..." -ForegroundColor Yellow
$WazuhSvcName = "WazuhSvc" 

if (Get-Service $WazuhSvcName -ErrorAction SilentlyContinue) {
    try {
        Restart-Service -Name $WazuhSvcName -Force
        Write-Host "[V] EXITO: Agente Wazuh reiniciado." -ForegroundColor Green
        Write-Host "    El equipo ahora reportara eventos avanzados." -ForegroundColor Cyan
    }
    catch {
        Write-Host "[X] ERROR: No se pudo reiniciar el servicio WazuhSvc. Reinicia manualmente con Restart-Service -Name WazuhSvc o NET STOP WazuhSvc y NET START WazuhSvc." -ForegroundColor Red
    }
}
else {
    Write-Host "[!] ALERTA: No se encontro el servicio 'WazuhSvc'." -ForegroundColor Yellow
}
