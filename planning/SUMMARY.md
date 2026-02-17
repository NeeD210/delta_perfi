# PerFi Delta - Resumen del Proyecto

## Resumen Ejecutivo

**PerFi Delta** es una herramienta de "Finanzas Zen" enfocada en la honestidad intelectual. No te pide categorizar gastos hormiga, sino que mide tu enriquecimiento real mes a mes mediante la diferencia patrimonial (`Delta NW`).

- **Target**: Usuarios argentinos, bimonetarios (ARS/USD).
- **Filosofía**: "No me digas en qué gasté, dime cuánto me enriquecí realmente".
- **URL Local**: http://localhost:4000

---

## Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| Backend | Elixir 1.19.5 + Phoenix 1.8.3 |
| Frontend | Phoenix LiveView (Mobile First) |
| Base de Datos | PostgreSQL 16 (Docker) |
| Estilos | Tailwind CSS 4.1 + DaisyUI 5.0 (Glassmorphism) |
| Autenticación | phx.gen.auth |

---

## Funcionalidades Principales

### 1. Onboarding "Zen" (Configuración Inicial)
- [x] Wizard de 8 pasos sin fricción.
- [x] **Presets de Inversión**: Selección rápida de Bitcoin, Ethereum, USDT, S&P 500, FCI.
- [x] **Carga Inteligente**: Conversión automática ARS -> USD (Blue).
- [x] **Deuda vs Pasivos**: Separación clara de cuentas de deuda.

### 2. El Ritual de Cierre Mensual
- [x] **Paso 0 - Cotizaciones**: Fetch automático Blue/MEP.
- [x] **Paso 1 - Activos**: Actualización rápida de saldos.
- [x] **Paso 2 - Pasivos**: Input diferenciado "Vence este mes" vs "Cuotas Futuras".
- [x] **Paso 3 - Flujos**: Registro de inyecciones/retiros de capital (Crucial para yield real).
- [x] **Paso 4 - Ingresos**: Carga de ingreso mensual.
- [x] **Paso 5 - Score**: Cálculo de Net Worth, Ahorro Real y Rendimiento.

### 3. Motores Financieros
- [x] **Gestión de Cuentas**: Soporte ARS, USD, BTC, ETH, SOL, USDT.
- [x] **Snapshot Engine**: Cálculo inmutable de métricas patrimoniales.
- [x] **Exchange Rates**: Cache local de cotizaciones para evitar límites de API.

### 4. UI/UX & Analytics
- [x] **Dashboard**: Vista de pájaro del estado actual.
- [x] **Zero State**: Onboarding inteligente para usuarios nuevos sin historial.
- [x] **Runway**: Indicador de "Libertad Financiera" (meses de vida según capital líquido).
- [x] **Historial**: Gráfico de evolución de patrimonio (últimos 12 meses).
- [x] **Snapshots**: Detalle profundo de cada cierre pasado.
- [x] **Diseño**: Tema oscuro/glassmorphism con colores semánticos (Verde Ahorro, Azul Yield, Rojo Ahorro).

### 5. Autenticación, Seguridad & Infraestructura
- [x] Flujo completo de Auth (Registro, Login, Recovery).
- [x] **Email**: Integración con Resend (Swoosh adapter) para confirmación y recuperación.
- [x] Soft Deletes para preservar integridad histórica.
- [ ] **Deploy**: Configuración de Fly.io (En proceso de debugging activo).

---

## Pendientes vs PRD (Gap Analysis)

### Prioridad Alta
- [ ] **Deploy a Producción**: Estabilizar deployment en Fly.io (Build & Runtime errors).
- [ ] **Landing Page**: Home pública optimizada para conversión.
- [ ] **Configuración de Moneda**: UI para elegir si usar Blue o MEP como referencia.
- [ ] **Validaciones Backend**: Reforzar integridad de snapshots en el Contexto.
- [ ] **Testing**: Tests unitarios para el motor de cálculo (`Finance.calculate_snapshot_values`).

### Prioridad Media/Baja (Post-MVP)
- [ ] **Automatización**: Flag `is_automated` para futuras integraciones.
- [ ] **Exportación**: CSV/Excel de los datos.
- [ ] **PWA**: Instalación en móvil.

---

## Modelo de Datos

```
Users
├── FinancialAccounts (Líquida, Inversión, Deuda)
└── Snapshots (Foto mensual)
    ├── AccountBalances (Saldo de cada cuenta)
    │   └── LiabilityDetails (Detalle de deuda para tarjetas)
    └── InvestmentFlows (Depósitos/retiros de capital)

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

# Ir al directorio
cd perfi_delta

# Setup inicial
mix deps.get
mix ecto.setup

# Iniciar server
mix phx.server
```

### URLs de Desarrollo
- App: http://localhost:4000
- LiveDashboard: http://localhost:4000/dev/dashboard
- Mailbox (Emails): http://localhost:4000/dev/mailbox
- Force Clean: `mix accounts.cleanup`

---

## Estructura del Proyecto

```
perfi_delta/
├── lib/
│   ├── perfi_delta/
│   │   ├── accounts/          # Auth
│   │   ├── finance/           # Core: Accounts, Snapshots, Calc Engine
│   │   ├── services/          # External APIs (Exchange Rates)
│   │   └── finance.ex         # Public API / Context
│   └── perfi_delta_web/
│       ├── helpers/           # NumberHelpers (formateo centralizado)
│       ├── live/              # LiveViews (Onboarding, Wizard, Dashboard)
│       └── components/        # UI Kit (Glassmorphism)
```

---

## Notas Técnicas
1. **Precisión**: Todo cálculo monetario usa `Decimal`.
2. **Moneda Base**: DB normalizada a **USD**. ARS se convierte al vuelo en el cierre.
3. **NumberHelpers**: Módulo centralizado (`PerfiDeltaWeb.Helpers.NumberHelpers`) para parseo y formateo numérico. Los LiveViews importan solo las funciones necesarias — NO redefinir helpers locales.
4. **Symlinks**: Si ves warnings en Windows, ejecutá PowerShell como Admin.
5. **Proxy**: Si fallan descargas, usar `curl --noproxy "*"`.
