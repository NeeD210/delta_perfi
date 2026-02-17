# Problema de Migraciones en Fly.io

**Estado:** 🛑 Bloqueante
**Contexto:** La aplicación está desplegada y "Healthy" (verde), pero la base de datos no tiene las tablas porque las migraciones fallan.

## Síntoma
Al ejecutar el comando de migración (ya sea `eval` o `rpc`):
```powershell
fly ssh console -C "/app/bin/perfi_delta eval PerfiDelta.Release.migrate"
```

Se obtiene un error `SystemLimitError` o crash silencioso, y en los intentos recientes un error genérico `(Ecto.MigrationError)` o `nofile`.
El error específico capturado en logs anteriores fue:
```text
** (Ecto.MigrationError) ... nofile:1: (file)
```

## Investigaciones Realizadas (Actualizado)

1.  **Existencia de Archivos:** Confirmada en `/app/lib/perfi_delta-0.1.0/priv/repo/migrations`.
2.  **Error de Conexión a DB:** Se identificó un error `nxdomain` al intentar conectar a `perfi-delta-db.flycast:5432`.
    - **Causa:** El dominio `.flycast` no resolvía correctamente desde el contenedor de la aplicación.
    - **Solución:** Cambiar el host en `DATABASE_URL` de `.flycast` a `.internal`.
3.  **Debug en Código:** Se añadió `Logger` en `release.ex` para diagnosticar el path de migraciones una vez que la conexión sea estable.

## Hipótesis Actualizada

1.  **DNS/Network (Confirmado):** El problema inmediato era la incapacidad de resolver la base de datos a través de Flycast.
2.  **Path de Migraciones:** Una vez resuelta la conexión, verificaremos si `Application.app_dir` sigue devolviendo `nofile` o si era un efecto secundario de la falla de conexión inicial.

## Plan de Acción Ejecutado

1.  **Corrección de Secreto:** Se actualizó `DATABASE_URL` manualmente para usar `perfi-delta-db.internal`.
2.  **Redeploy Local:** Debido a inestabilidad en el builder remoto de Fly, se optó por `fly deploy --local-only`.
3.  **Verificación de Logs:** Monitorear `fly logs` para confirmar la conexión exitosa y la ejecución de `Ecto.Migrator`.