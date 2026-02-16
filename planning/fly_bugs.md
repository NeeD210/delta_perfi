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

- La aplicación se está desplegando con el `release_command` **comentado** para intentar levantarla primero sin migraciones automáticas.
- **Objetivo Inmediato:** Lograr que la app arranque y quede "verde" en Fly.io.
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
