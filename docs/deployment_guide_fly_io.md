# Guía de Despliegue en Fly.io para PerFi Delta

Este documento detalla el proceso correcto y las configuraciones necesarias para desplegar la aplicación `perfi_delta` en Fly.io, basado en la experiencia de resolución de problemas recientes.

## 1. Prerrequisitos

*   **flyctl**: La herramienta de línea de comandos de Fly.io debe estar instalada y autenticada (`fly auth login`).
*   **Docker**: Necesario si se compila localmente (aunque Fly.io generalmente usa builders remotos).

## 2. Configuración Esencial (`fly.toml`)

El archivo `fly.toml` es el corazón del despliegue. Para evitar errores comunes (`nxdomain`, `deadline_exceeded`, `Critical Health`), debe tener las siguientes configuraciones clave:

### Variables de Entorno y Red
La aplicación necesita **IPv6** para conectarse a la base de datos interna de Fly.io.

```toml
[env]
  PHX_HOST = 'perfi-delta.fly.dev'
  PORT = '8080'
  ECTO_IPV6 = 'true'  # ¡CRÍTICO! Habilita IPv6 en Ecto para resolver .internal
```

### Recursos de la Máquina (VM)
Las migraciones y el arranque de Phoenix pueden consumir más de 512MB. Se recomienda **1GB** para estabilidad.

```toml
[[vm]]
  memory = '1024mb'   # Necesario para evitar OOM (Out Of Memory) durante el arranque/migración
  cpu_kind = 'shared'
  cpus = 1
```

### Health Checks (Verificaciones de Salud)
Phoenix con `Plug.SSL` fuerza redirecciones a HTTPS. El health check interno de Fly puede fallar con un 301 si no se envía el header correcto.

```toml
[[http_service.checks]]
  grace_period = "20s"
  interval = "15s"
  method = "GET"
  path = "/health"
  headers = { Host = "localhost" } # ¡IMPORTANTE! Evita el redirect 301 https://...
  timeout = "5s"
```

### Comando de Release (Migraciones Automáticas)
Idealmente, las migraciones se ejecutan automáticamente antes del despliegue.
**Nota:** Actualmente está comentado debido a problemas de timeout (`deadline_exceeded`) en las máquinas efímeras de Fly.io.

```toml
[deploy]
  # release_command = '/app/bin/migrate' 
```

---

## 3. Gestión de Secretos

Antes del primer despliegue, asegúrate de que estos secretos estén configurados en Fly.io:

```bash
# 1. Base de datos (generalmente se configura sola al hacer attach)
fly secrets set DATABASE_URL=ecto://user:pass@hostname:5432/db_name

# 2. Secret Key Base de Phoenix
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)

# 3. API Key de Resend (Emails)
fly secrets set RESEND_API_KEY=re_123456789
```

---

## 4. Proceso de Despliegue

### Paso 1: Desplegar la Aplicación
Ejecuta el siguiente comando en la raíz del proyecto:

```bash
fly deploy
```

Si el `release_command` está comentado en `fly.toml`, este comando solo actualizará el código de la aplicación.

### Paso 2: Ejecutar Migraciones (Manual - Recomendado si falla el automático)
Debido a la inestabilidad de las máquinas de release, el método más seguro actualmente es ejecutar la migración **dentro** de la máquina ya desplegada y saludable.

1.  Asegúrate de que el deploy terminó y la app está "Healthy".
2.  Conéctate vía SSH y ejecuta el script de migración:

```powershell
fly ssh console -C "/app/bin/migrate"
```

Alternativamente, si el comando directo falla, entra a la consola interactiva:

```powershell
fly ssh console
# Una vez dentro de la terminal Linux:
/app/bin/migrate
exit
```

---

## 5. Solución de Problemas Comunes

| Síntoma | Causa Probable | Solución |
| :--- | :--- | :--- |
| **Error `nxdomain`** | La app intenta usar IPv4 para conectar a la DB `.internal` (que es IPv6). | Asegurar `ECTO_IPV6 = 'true'` en `fly.toml` y que `config/runtime.exs` lo use. |
| **Error `deadline_exceeded`** | La máquina tarda mucho en arrancar o se queda sin memoria. | Aumentar memoria a `1024mb` en `fly.toml`. Si ocurre en release_command, hacerlo manual. |
| **Status `Critical` (Health Check 301)** | El health check recibe un redirect HTTPS en lugar de 200 OK. | Agregar `headers = { Host = "localhost" }` en la sección `[http_service.checks]` de `fly.toml`. |
| **Deploy falla en "Building image"** | Problemas con el builder remoto. | Intentar `fly deploy --local-only` (requiere Docker local). |

---

## 6. Referencia de Archivos Clave

*   `fly.toml`: Configuración de infraestructura.
*   `config/runtime.exs`: Configuración dinámica de Elixir (lee variables de entorno).
*   `lib/perfi_delta/release.ex`: Módulo que define la lógica de ejecución de migraciones.
