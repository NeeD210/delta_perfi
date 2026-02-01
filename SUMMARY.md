# PerFi Delta - Resumen del Proyecto

## Visión General

**PerFi Delta** es una herramienta de "Finanzas Zen" que calcula el flujo de dinero por diferencia patrimonial. A diferencia de los rastreadores de gastos tradicionales, se enfoca en medir el enriquecimiento real del usuario.

- **Target**: Usuarios argentinos, bimonetarios (ARS/USD)
- **Filosofía**: "No me digas en qué gasté, dime cuánto me enriquecí realmente"
- **URL Local**: http://localhost:4000

---

## Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| Backend | Elixir 1.19.5 + Phoenix 1.8.3 |
| Frontend | Phoenix LiveView |
| Base de Datos | PostgreSQL 16 (Docker) |
| Estilos | Tailwind CSS 4.1 + DaisyUI 5.0 |
| Autenticación | phx.gen.auth (LiveView) |

---

## Funcionalidades Implementadas

### 1. Autenticación
- [x] Registro de usuarios con email/password
- [x] Login/Logout (Magic Link + Password)
- [x] Confirmación de email (dev mailbox en `/dev/mailbox`)
- [x] Reenvío de email de confirmación
- [x] Limpieza automática de cuentas no confirmadas (7 días)
- [x] Cambio de contraseña
- [x] Recuperación de cuenta
- [x] Configuración de emails reales (Resend)

### 2. Gestión de Cuentas Financieras
- [x] CRUD de cuentas (crear, editar, eliminar)
- [x] Tipos de cuenta: Líquida, Inversión, Deuda
- [x] Monedas soportadas: ARS, USD, USDT, BTC, ETH, SOL
- [x] Soft delete para preservar historial

### 3. Servicio de Cotizaciones
- [x] Integración con DolarApi (Blue, MEP, Oficial)
- [x] Integración con Binance (BTC, ETH, SOL)
- [x] Cache de cotizaciones en base de datos
- [x] Conversión automática a USD

### 4. Wizard de Cierre Mensual
- [x] Paso 0: Fetch de cotizaciones automático
- [x] Paso 1: Actualización de saldos de activos
- [x] Paso 2: Registro de pasivos con detalle de cuotas
- [x] Paso 3: Flujos de inversión (depósitos/retiros)
- [x] Paso 4: Ingreso del mes
- [x] Paso 5: Resultado con cálculos

### 5. Motor de Cálculo (Snapshot Engine)
- [x] Net Worth = Σ Activos - Σ Pasivos
- [x] Delta NW = NW_actual - NW_anterior
- [x] Yield = NW_actual - (NW_anterior + NetFlows)
- [x] Savings = Delta NW - Yield
- [x] Expenses = Income - Savings

### 6. UI/UX
- [x] Diseño Mobile-First
- [x] Estética "Zen" (minimalista, blanco/negro)
- [x] Colores semánticos: Verde (ahorro), Azul (rendimiento), Rojo (deuda)
- [x] Navegación inferior fija
- [x] Inputs numéricos optimizados para móvil
- [x] Dark mode automático

### 7. Páginas
- [x] Landing page (usuarios no autenticados)
- [x] Dashboard principal con resumen
- [x] Gestión de cuentas
- [x] Wizard de cierre mensual
- [x] Historial de snapshots
- [x] Onboarding para nuevos usuarios

---

## Modelo de Datos

```
Users
├── FinancialAccounts (Líquida, Inversión, Deuda)
└── Snapshots (Foto mensual)
    ├── AccountBalances (Saldo de cada cuenta)
    │   └── LiabilityDetails (Detalle de deuda para tarjetas)
    └── InvestmentFlows (Depósitos/Retiros)

ExchangeRates (Cache de cotizaciones)
```

---

## Cómo Ejecutar

### Requisitos
- Elixir 1.16+
- PostgreSQL (recomendado vía Docker)
- Docker Desktop

### Comandos

```powershell
# Iniciar PostgreSQL
docker start perfi-postgres

# Ir al directorio del proyecto
cd perfi_delta

# Instalar dependencias (si es necesario)
mix deps.get

# Crear/migrar base de datos
mix ecto.reset

# Iniciar servidor
mix phx.server
```

### URLs
- App: http://localhost:4000
- LiveDashboard: http://localhost:4000/dev/dashboard
- Mailbox (dev): http://localhost:4000/dev/mailbox
- Reenviar confirmación: http://localhost:4000/users/resend-confirmation

### Mantenimiento

```powershell
# Limpiar cuentas no confirmadas (>7 días) y tokens expirados
mix accounts.cleanup

# Limpiar cuentas más antiguas (ej: 30 días)
mix accounts.cleanup --days 30
```

---

## Pendiente (Post-MVP)

### Alta Prioridad
- [ ] Validación de formularios más robusta en el wizard
- [ ] Manejo de errores de red en el servicio de cotizaciones
- [ ] Tests unitarios para el motor de cálculo
- [ ] Tests de integración para el wizard

### Media Prioridad
- [ ] Gráficos de evolución del patrimonio (Chart.js o similar)
- [ ] Exportación de datos a CSV/Excel
- [ ] Notificaciones para recordar el cierre mensual
- [ ] Cotización MEP como alternativa al Blue

### Baja Prioridad
- [ ] Automatización de cuentas (`is_automated: true`)
- [ ] APIs de fallback para cotizaciones
- [ ] Internacionalización (otros países/idiomas)
- [ ] PWA (Progressive Web App)

---

## Cosas a Tener en Cuenta

### 1. Proxy del Sistema
Tu sistema tiene configuración de proxy que interfiere con descargas. Si necesitas reinstalar dependencias:

```powershell
# Usar curl con --noproxy para descargas
curl.exe --noproxy "*" -L -o archivo.tgz "URL"
```

### 2. Symlinks en Windows
Phoenix muestra warnings sobre symlinks. Para solucionarlo, ejecutá PowerShell como Administrador al menos una vez. No afecta la funcionalidad.

### 3. Docker PostgreSQL
El contenedor de PostgreSQL puede detenerse al reiniciar. Antes de iniciar la app:

```powershell
docker start perfi-postgres
```

### 4. Precisión Decimal
Todos los cálculos monetarios usan `Decimal` (nunca `Float`) para evitar errores de precisión.

### 5. Soft Delete
Las entidades no se eliminan físicamente, solo se marca `deleted_at`. Esto preserva el historial y la integridad referencial.

### 6. Timezone
La app usa `America/Argentina/Buenos_Aires` para determinar el mes actual del cierre.

### 7. Moneda Base
La base de datos normaliza todo a **USD**. Los valores en ARS se convierten usando el dólar blue al momento del cierre.

### 8. Sistema de Emails
**Desarrollo**: Los emails se capturan localmente en `/dev/mailbox`

**Producción**: Configurado para usar [Resend](https://resend.com) (3000 emails gratis/mes)

Para habilitar emails reales en producción:
```bash
# 1. Crear cuenta en https://resend.com
# 2. Obtener API key del dashboard
# 3. Configurar variables de entorno:
export RESEND_API_KEY="tu_api_key_aqui"
export FROM_EMAIL="noreply@tudominio.com"  # Opcional
```

**Protecciones contra cuentas bloqueadas:**
- Página de reenvío de confirmación: `/users/resend-confirmation`
- Links automáticos en errores de registro
- Limpieza automática de cuentas no confirmadas después de 7 días
- Task manual: `mix accounts.cleanup`

---

## Estructura del Proyecto

```
perfi_delta/
├── lib/
│   ├── perfi_delta/
│   │   ├── accounts/          # Auth (Users, Tokens)
│   │   ├── finance/           # Core del negocio
│   │   │   ├── financial_account.ex
│   │   │   ├── snapshot.ex
│   │   │   ├── account_balance.ex
│   │   │   ├── liability_detail.ex
│   │   │   ├── investment_flow.ex
│   │   │   └── exchange_rate.ex
│   │   ├── finance.ex         # Contexto y motor de cálculo
│   │   └── services/
│   │       └── exchange_rate_service.ex
│   └── perfi_delta_web/
│       ├── live/
│       │   ├── dashboard_live.ex
│       │   ├── accounts_live.ex
│       │   ├── closure_wizard_live.ex
│       │   ├── history_live.ex
│       │   └── onboarding_live.ex
│       └── components/
│           └── layouts/
├── priv/repo/migrations/
└── assets/css/app.css         # Estilos personalizados
```

---

## Contacto y Desarrollo

Proyecto creado siguiendo el PRD de "PerFi Delta (MVP)".

Para continuar el desarrollo:
1. Lee el PRD.md para contexto completo
2. Usa `mix test` para correr tests
3. Usa `mix format` antes de commitear
4. El LiveDashboard (`/dev/dashboard`) es útil para debugging
