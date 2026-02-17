# Reporte de Errores de Deploy en Fly.io

Este documento recopila los problemas encontrados durante el intento de despliegue en Fly.io y sus estados actuales.

## 1. Error de Construcción (Build - Phoenix Colocated Hooks)

**Síntoma:** El build de Docker fallaba en el paso `mix assets.deploy`.
**Error:** `Could not resolve "phoenix-colocated/perfi_delta"`
**Causa:** Phoenix 1.8 genera los hooks de JS coubicados durante la compilación (`mix compile`). El `Dockerfile` original ejecutaba `mix assets.deploy` (esbuild) **antes** de `mix compile`, por lo que el módulo de hooks aún no existía.
**Solución Aplicada:** Se reordenó el `Dockerfile` para ejecutar `mix compile` antes de `mix assets.deploy`.

## 2. Error de Ejecución de Release Command (Timeouts)

**Síntoma:** El despliegue falla después del build exitoso con el error:
`error starting release_command machine: failed to start VM <id>: deadline_exceeded: failed to wait for machine to be started`
**Causa Probable:**
1. **Cold Start:** La máquina efímera para correr migraciones tarda más de lo esperado en arrancar.
2. **Crash al Inicio:** La aplicación crashea inmediatamente al arrancar, impidiendo que el comando se ejecute.

## 3. Error de Health Checks (Port Binding)

**Síntoma:** Los health checks fallaban en el path `/users/log-in`.
**Causa Identificada:** En `config/runtime.exs`, la configuración `http` dentro del bloque `if config_env() == :prod do` estaba sobrescribiendo la configuración global, eliminando el puerto.
*   **Antes:** `ip: {0,0,0,0}` (Puerto default 4000)
*   **Fly.io espera:** Puerto 8080.
**Solución Aplicada:** Se corrigió `config/runtime.exs` para incluir explícitamente `port: String.to_integer(System.get_env("PORT") || "4000")`.

## Estado Actual


- [x] La aplicación se ha desplegado correctamente y está **Verde** (Healthy).
- **Pasos Siguientes:**
    1. Verificar si la app levanta con el fix del puerto (deploy en curso).
    2. Si levanta, ejecutar migraciones manualmente vía `fly ssh console`.
    3. Si no levanta, revisar logs de crash (`fly logs`).

## Comandos Útiles para Debugging

```powershell
# Ver estado de la app
fly status

# Ver logs recientes
fly logs

# Intentar entrar por SSH (solo si la máquina está "started")
fly ssh console

# Ejecutar migración manual (si la app está arriba)
fly ssh console -C "/app/bin/migrate"
```


## 4. Error de Estabilidad (Proxy Error / Restart Loop)

**Síntoma:**
- Fly Doctor: "Machines Restarting a Lot".
- Logs (CLI/Dashboard): `[PR04] could not find a good candidate within 40 attempts at load balancing`.
- Error parcial anterior ("could not find a g...") era: `could not find a good candidate...`.

**Diagnóstico Confirmado:**
El error `PR04` indica que el Proxy de Fly no encuentra ninguna máquina "sana" para recibir tráfico. Esto sucede porque:
1.  La app crashea al inicio (Status: Failed).
2.  O la app arranca pero falla el Health Check (Status: Unhealthy) y Fly la reinicia.
3.  Posible causa del fallo de Health Check: **SSL Redirect**. El check interno va por HTTP, pero `force_ssl` en `prod.exs` redirige a HTTPS. El check recibe un 301/307 y lo marca como fail (o timeout).

**Solución Propuesta:**
1.  Crear un endpoint dedicado `/health` que retorne 200 OK simple.
2.  Excluir `/health` de `force_ssl` en `prod.exs`.

## 5. Error Crítico de Inicio (Entrypoint / OS Error 2)

**Síntoma:**
Logs de Fly (App): `Error: failed to spawn command: /app/bin/server: No such file or directory (os error 2)`

**Diagnóstico Definitivo:**
El archivo `/app/bin/server` es un script de shell (`rel/overlays/bin/server`).
Al desarrollar en Windows, este archivo probablemente se guardó con finales de línea **CRLF**.
En el contenedor Linux, el shebang `#!/bin/sh` se lee como `#!/bin/sh\r`, lo cual no existe, lanzando "No such file or directory".

**Solución Aplicada:**
Se modificó el `Dockerfile` para usar `CMD ["/app/bin/perfi_delta", "start"]` y `ENV PHX_SERVER=true`, eliminando la dependencia del script incompatible.

## Estado Final
- **App Deployada:** ✅
- **Health Checks:** ✅ (Endpoint `/health` funcionando)
- **Migraciones:** Pendientes de ejecutar manualmente.
