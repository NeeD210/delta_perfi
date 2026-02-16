# Configuración de Emails - PerFi Delta

Este documento explica cómo configurar el envío de emails reales para producción usando Resend.

## 🚀 Resumen Rápido

1. Crear cuenta en [Resend](https://resend.com)
2. Obtener API Key
3. Configurar variables de entorno
4. Desplegar

---

## 📧 Sistema de Emails

### Desarrollo (Local)

Por defecto, en desarrollo los emails **NO se envían realmente**. Se capturan en un mailbox local:

```
http://localhost:4000/dev/mailbox
```

**Ventajas:**
- No necesitas configurar nada
- Ves los emails inmediatamente en el navegador
- No gastas tu cuota de emails

**Desventaja:**
- Los emails se pierden al reiniciar el servidor

### Producción (Resend)

Usamos **Resend** porque:
- ✅ 3,000 emails gratis por mes
- ✅ Excelente developer experience
- ✅ API moderna y simple
- ✅ No requiere verificación de dominio para empezar

---

## 🔧 Configuración de Resend

### Paso 1: Crear cuenta

1. Ve a [resend.com](https://resend.com)
2. Crea una cuenta (gratis)
3. Confirma tu email

### Paso 2: Obtener API Key

1. En el dashboard de Resend, ve a **API Keys**
2. Click en **Create API Key**
3. Dale un nombre (ej: "PerFi Delta Production")
4. Copia la API key (empieza con `re_...`)

⚠️ **IMPORTANTE:** Guarda esta key de forma segura. Solo se muestra una vez.

### Paso 3: Configurar Variables de Entorno

#### En tu servidor de producción (ej: Vercel, Fly.io, Railway):

```bash
RESEND_API_KEY=re_tu_api_key_aqui
FROM_EMAIL=noreply@tudominio.com  # Opcional
```

#### Para probar localmente con Resend:

```powershell
# Windows PowerShell
$env:RESEND_API_KEY="re_tu_api_key_aqui"
$env:FROM_EMAIL="noreply@tudominio.com"
mix phx.server
```

```bash
# Linux/Mac
export RESEND_API_KEY="re_tu_api_key_aqui"
export FROM_EMAIL="noreply@tudominio.com"
mix phx.server
```

### Paso 4: Email "From"

**Opción 1: Usar el dominio por defecto de Resend (más fácil)**

Si no configuras `FROM_EMAIL`, se usará: `onboarding@resend.dev`

✅ Funciona inmediatamente, sin configuración adicional

**Opción 2: Usar tu propio dominio (más profesional)**

1. En Resend, ve a **Domains**
2. Agrega tu dominio (ej: `tuapp.com`)
3. **Configuración DNS (Paso Crítico):**
   Resend te dará 3 registros técnicos que tenés que copiar y pegar en tu proveedor de dominio (Porkbun, etc.):
   - **DKIM (TXT):** Firma digital para que los receptores confíen en el mail.
   - **SPF (TXT):** Lista de servidores autorizados para mandar mails de tu dominio.
   - **DMARC (TXT):** Política de seguridad que dice qué hacer si falla el SPF/DKIM.
4. Espera la verificación (5-30 minutos)
5. Configura `FROM_EMAIL=noreply@tuapp.com` en tu archivo `.env`
   
> [!NOTE]
> Configurar el dominio para email (registros TXT) **no afecta** a tu sitio web. Son "puertas" separadas en la misma casa.

---

## 🛡️ Protección contra Bloqueos de Cuenta

### Problema que resolvimos

**Antes:**
1. Usuario se registra con `juan@email.com`
2. Servidor se cae / mailbox vacío
3. Usuario no recibe email
4. Usuario intenta registrarse de nuevo
5. ❌ Error: "Email ya en uso"
6. Usuario queda bloqueado

**Ahora:**
1. Usuario se registra con `juan@email.com`
2. No recibe el email (por cualquier motivo)
3. ✅ Puede ir a `/users/resend-confirmation`
4. ✅ Recibe un nuevo email
5. ✅ Alternativamente, la cuenta se auto-limpia en 7 días

### Características Implementadas

#### 1. Página de Reenvío

```
http://localhost:4000/users/resend-confirmation
```

El usuario puede ingresar su email y recibir un nuevo enlace de confirmación.

#### 2. Links Automáticos

Si un usuario intenta registrarse con un email ya existente pero no confirmado, verá:

```
⚠️ Este email ya está registrado pero no confirmado.
   ¿Reenviar email de confirmación?
```

#### 3. Limpieza Automática

Las cuentas no confirmadas se eliminan automáticamente después de 7 días.

**Ejecutar manualmente:**

```powershell
# Limpiar cuentas no confirmadas (>7 días)
mix accounts.cleanup

# Limpiar cuentas más antiguas
mix accounts.cleanup --days 30
```

**Programar automáticamente:**

En producción, agrega esto a tu cron o scheduler:

```bash
# Linux cron (diario a las 3 AM)
0 3 * * * cd /ruta/app && mix accounts.cleanup
```

---

## 📊 Monitoreo

### Ver emails enviados en Resend

1. Ve al dashboard de Resend
2. Click en **Logs**
3. Verás todos los emails enviados, abiertos, y bounces

### Cuota de emails

- Plan gratuito: **3,000 emails/mes**
- Ver uso actual: Dashboard de Resend
- Si necesitas más: Planes desde $10/mes

---

## 🧪 Probar en Desarrollo

### Opción 1: Mailbox Local (por defecto)

```powershell
mix phx.server
# Visita: http://localhost:4000/dev/mailbox
```

### Opción 2: Resend Real (para probar)

```powershell
$env:RESEND_API_KEY="re_tu_api_key"
mix phx.server
```

Los emails se enviarán de verdad (cuentan en tu cuota).

---

## 🚨 Troubleshooting

### "Email no se envía"

1. **En desarrollo sin RESEND_API_KEY:** ✅ Normal, revisa `/dev/mailbox`
2. **En producción:** Verifica que `RESEND_API_KEY` esté configurada
3. **Revisa logs de Resend:** Dashboard > Logs

### "Email llega a spam"

- Si usas `onboarding@resend.dev`: Es común inicialmente
- Solución: Configura tu propio dominio en Resend
- Agrega registros SPF, DKIM, DMARC (Resend te da las instrucciones)

### "Usuario reporta que no recibió email"

1. Pregunta si revisó spam
2. Verifica en Resend Logs si se envió
3. Ofrece usar `/users/resend-confirmation`
4. Si el problema persiste, verifica que el email sea válido

---

## 📝 Notas Importantes

1. **Seguridad:** Nunca commits tu `RESEND_API_KEY` en Git
2. **Rate Limits:** Resend tiene límites de rate (100 emails/segundo en plan gratuito)
3. **Bounce Handling:** Resend automáticamente maneja bounces
4. **Unsubscribes:** Para emails marketing, agrega header `List-Unsubscribe`

---

## 🔗 Enlaces Útiles

- [Resend Docs](https://resend.com/docs)
- [Swoosh Resend Adapter](https://hexdocs.pm/swoosh/Swoosh.Adapters.Resend.html)
- [Resend Dashboard](https://resend.com/home)

---

## 💡 Mejoras Futuras

- [ ] Plantillas HTML para emails (actualmente son texto plano)
- [ ] Tracking de aperturas de email
- [ ] Email de bienvenida después de confirmar
- [ ] Recordatorios automáticos de cierre mensual
- [ ] Reportes mensuales por email
