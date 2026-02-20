# 🔍 Análisis de Error de Registro (2026-02-19)

Este documento resume el estado del error de registro reportado al final de la jornada para su resolución inmediata mañana.

## 🚨 El Problema
Al intentar registrar un usuario en `perfi.com.ar/users/register`, la LiveView crashea.

### Stack Trace
- **Archivo**: `lib/perfi_delta_web/live/user_live/registration.ex:46`
- **Error**: Ocurre dentro de la función anónima generada por el bucle `:for` de errores.
- **Línea 46**: `<.error :for={msg <- @form[:email].errors}><%= msg %></.error>`

## 🔬 Hipótesis Actuales

### 1. Misuso de `temporary_assigns` (Alta Probabilidad)
El módulo `Registration` tiene configurado `temporary_assigns: [form: nil]`. 
- **Efecto**: LiveView resetea `@form` a `nil` inmediatamente después de renderizar para ahorrar memoria.
- **Problema**: Si ocurre un evento de guardado que falla o un re-render parcial, `@form` puede ser `nil`, haciendo que `@form[:email]` devuelva `nil` y `@form[:email].errors` lance un error al intentar acceder a una propiedad de algo que no existe.
- **Solución**: Quitar `form: nil` de `temporary_assigns`. Las formas NO deben ser temporales si queremos mostrar errores de validación.

### 2. Fallo de Escritura en LiteFS (Media Probabilidad)
Incluso con una sola máquina, si LiteFS no ha montado correctamente el volumen `/data` como lectura/escritura (o si hay un problema de permisos), el comando `Repo.insert` fallará.
- **Efecto**: El proceso del LiveView muere antes de completar el `handle_event`.
- **Dato**: El stack trace muestra el error en `render/1`, lo que sugiere que el crash ocurre durante el intento de generar el HTML de respuesta tras el fallo.

### 3. Fallo en el Despliegue Local
El comando `fly deploy` falló localmente (Exit code 1).
- **Consecuencia**: No pudimos aplicar el parche de "Detailed Logging" que nos daría el error exacto de la base de datos o del Mailer.

## 🛠️ Acciones para Mañana

1.  **Corregir `registration.ex`**: Eliminar `temporary_assigns: [form: nil]` en la línea 93.
2.  **Verificar LiteFS**: Ejecutar `fly ssh console` y correr `ls -la /data` para verificar que la DB existe y tiene permisos de escritura.
3.  **Depurar `fly deploy`**: Entender por qué falla el build local (probablemente Docker o memoria en Windows).
4.  **Revisar `UserNotifier`**: Confirmar que `hola@perfi.com.ar` tiene permisos de envío en el dashboard de Resend (que el dominio `perfi.com.ar` esté en estado `Verified`).

---
**Estado de Infraestructura**: 1 Máquina (Scale count 1) en región `gru`.
**URL**: [perfi.com.ar](https://perfi.com.ar)
