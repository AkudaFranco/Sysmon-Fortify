# 🛡️ Despliegue Automatizado de Sysmon e Integración con Wazuh

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg) ![Sysmon](https://img.shields.io/badge/Sysinternals-Sysmon-red.svg) ![Wazuh](https://img.shields.io/badge/Integration-Wazuh-blueviolet.svg) ![Status](https://img.shields.io/badge/Status-Production%20Ready-success.svg)

## 📋 Descripción General

Este script de PowerShell proporciona una estrategia de despliegue **robusta, automatizada y con capacidad de auto-reparación** para Microsoft Sysmon en entornos Windows críticos. Está diseñado específicamente para endpoints de alta seguridad donde la visibilidad es prioritaria (Estrategia de Defensa en Profundidad).

A diferencia de los instaladores estándar, este script gestiona escenarios de fallo comunes (como manifiestos corruptos o instalaciones previas sucias), aplica automáticamente configuraciones estándar de la industria y se integra inmediatamente con el agente SIEM de Wazuh.

## ✨ Características Clave

* **🚀 Obtención Automatizada:** Descarga los binarios oficiales más recientes de Microsoft Sysinternals y la configuración optimizada de [SwiftOnSecurity](https://github.com/SwiftOnSecurity/sysmon-config).
* **❤️ Mecanismo de Auto-reparación (Self-Healing):** Incluye una capa lógica que detecta fallos en la instalación (ej: errores de *"Event manifest already exists"*). Si detecta un fallo, ejecuta automáticamente una **limpieza forzosa** (`-u force`) y reintenta la instalación sin intervención del usuario.
* **🌐 Visibilidad de Red:** Fuerza el flag `-n` durante la instalación para asegurar el registro de **Conexiones de Red (Event ID 3)**, vital para detectar movimientos laterales y beacons de C2.
* **🛡️ Integración con Wazuh:** Detecta y reinicia automáticamente el servicio `WazuhSvc` tras una instalación exitosa para asegurar que el agente comienza a ingerir los nuevos logs de inmediato.
* **✅ Verificación de Integridad:** Valida permisos de Administrador antes de la ejecución y verifica el estado del servicio post-instalación.
* **console-Safe:** Codificación de salida sanitizada para evitar errores de caracteres en diferentes configuraciones regionales de consola.

## 🛠️ Uso

### Requisitos Previos
* Windows PowerShell 5.1 o superior.
* **Permisos de Administrador** son obligatorios (el script incluye una verificación de seguridad y se detendrá si no está elevado).
* Conexión a Internet (para descargar binarios y configuración).

### Instalación

1.  Descarga el archivo `Install-Sysmon.ps1`.
2.  Abre PowerShell como **Administrador**.
3.  Ejecuta el script:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-Sysmon.ps1
```

## ⚙️ Cómo Funciona (Flujo Lógico)

1.  **Pre-flight Checks:** Verifica derechos de Admin y prepara el directorio de trabajo (`C:\Sysmon_Install`).
2.  **Descarga de Recursos:** Obtiene `Sysmon.zip` y `sysmonconfig-export.xml` usando TLS 1.2.
3.  **Bucle de Instalación Inteligente:**
    * Intenta la instalación estándar: `Sysmon64.exe -i config.xml -accepteula -l -n`
    * **SI TIENE ÉXITO:** Procede a la verificación.
    * **SI FALLA:** Activa la **Rutina de Auto-reparación**:
        1.  Ejecuta `Sysmon64.exe -u force` para purgar drivers y manifiestos corruptos.
        2.  Reintenta la instalación en limpio.
4.  **Verificación:** Consulta el estado del servicio `Sysmon64` para asegurar que está `Running`.
5.  **Recarga del SIEM:** Fuerza el reinicio del Agente Wazuh (`WazuhSvc`) para disparar la recarga de configuración y comenzar la ingesta de telemetría.

## 📝 Detalles de Configuración

El script aplica la configuración de **SwiftOnSecurity**, considerada el "Estándar de Oro" para reducir el ruido manteniendo eventos de seguridad de alta fidelidad.

* **Flags utilizados:**
    * `-i`: Instalar con archivo de configuración.
    * `-accepteula`: Aceptar licencia automáticamente.
    * `-l`: Registrar la carga de módulos.
    * `-n`: **Registrar Conexiones de Red** (Crítico para correlar anomalías de red con procesos).

## ⚠️ Solución de Problemas

Si encuentras problemas a pesar de la lógica de auto-reparación:
1.  Asegúrate de que ningún otro software de seguridad (AV/EDR) esté bloqueando el proceso `Sysmon64.exe`.
2.  Ejecuta manualmente `sc query SysmonDrv` para verificar si hay drivers del kernel "zombies" que requieran un reinicio del servidor.

---
*Desarrollado para operaciones internas de hardening. Úsese bajo su propia responsabilidad.*
