# Product Requirements Document (PRD): PerFi Delta (MVP)

## 1. Visión y Alcance
PerFi Delta es una herramienta de **"Finanzas Zen"** basada en la honestidad intelectual. A diferencia de los rastreadores de gastos tradicionales, Delta calcula el flujo de dinero por diferencia patrimonial.

- **Filosofía**: *"No me digas en qué gasté, dime cuánto me enriquecí realmente."*
- **Target**: Usuarios argentinos, bimonetarios (ARS/USD), que operan principalmente desde el móvil.
- **Objetivo del MVP**: Permitir al usuario realizar su primer "Cierre de Mes" con precisión contable, revelando deudas ocultas y rendimiento real de inversiones.

### 1.1 Configuración Regional (MVP)
- **Idioma**: Español (Argentina)
- **Timezone**: `America/Argentina/Buenos_Aires`
- **Cotización por defecto**: Dólar Blue (configurable a MEP en futuras versiones)

---

## 2. Stack Tecnológico (The Elixir Gold Standard)
Este stack está optimizado para desarrollo unipersonal rápido y estabilidad a largo plazo.

- **Lenguaje**: Elixir 1.16+ (OTP 26)
- **Framework Web**: Phoenix 1.7+
- **Frontend & Interacción**: Phoenix LiveView (Mobile-First Design)
- **Base de Datos**: PostgreSQL
- **ORM/Query Builder**: Ecto
- **Estilos**: Tailwind CSS (con clases `touch-manipulation` para móvil)
- **Componentes UI**: `core_components.ex` (Default de Phoenix) modificado para estética "Zen" (Blanco/Negro)
- **Infraestructura**: Fly.io (Cluster) o Render

---

## 3. Modelo de Datos (Ecto Schema)
El sistema debe manejar la **Bimonetariedad**. La moneda base de la base de datos será **USD**. Las entradas en ARS se convierten al vuelo al guardar el Snapshot, pero se preserva el valor original para referencia.

### 3.1 Entidades Principales

#### **Users**
- Autenticación estándar (`phx.gen.auth`).
- **Campos**: `email`, `hashed_password`, `deleted_at (timestamp)`.

#### **Accounts** (El Inventario)
Representa dónde está el dinero o la deuda.
- `user_id`: references `User`.
- `name`: string (Ej: "Galicia", "Binance BTC", "Visa").
- `type`: enum (`:liquid`, `:investment`, `:liability`).
- `currency`: string (monedas soportadas por las APIs: ARS, USD, USDT, BTC, etc.).
- `is_automated`: boolean (default `false`).
- `deleted_at`: timestamp (soft delete).

> **Patrón multi-cripto**: Si el usuario tiene varias criptos en un mismo exchange, se crean accounts separadas por moneda (Ej: "Binance BTC", "Binance ETH", "Binance USDT"). Esto simplifica la conversión a USD y preserva el historial por activo.

#### **Snapshots** (La Foto Mensual)
El registro inmutable del estado financiero.
- `user_id`: references `User`.
- `month`: integer.
- `year`: integer.
- `status`: enum (`:draft`, `:confirmed`).
- `total_income_usd`: decimal (Ingreso del mes).
- `total_net_worth_usd`: decimal (Calculado).
- `total_savings_usd`: decimal (Calculado).
- `total_yield_usd`: decimal (Calculado).
- `exchange_rate_blue`: decimal (Guardado para historia).
- `exchange_rate_mep`: decimal.
- `deleted_at`: timestamp (soft delete).
- **Unique constraint**: `(user_id, month, year)`.

#### **AccountBalances** (El Detalle)
- `snapshot_id`: references `Snapshot`.
- `account_id`: references `Account`.
- `amount_nominal`: decimal (Ej: 150,000 ARS).
- `amount_usd`: decimal (Valor normalizado al día del cierre).
- `deleted_at`: timestamp (soft delete).
- **Lógica**: Si `account.type == :liability`, el valor es negativo.

#### **LiabilityDetails** (El Iceberg de Deuda)
Tabla 1:1 con `AccountBalances` (solo para tarjetas de crédito).
- `account_balance_id`: references `AccountBalance`.
- `current_period_balance`: decimal (Lo que vence este mes).
- `future_installments_balance`: decimal (Cuotas futuras).
- `total_debt`: decimal (Suma de ambos, debe coincidir con `AccountBalances.amount_nominal`).
- `deleted_at`: timestamp (soft delete).

#### **InvestmentFlows** (La Corrección)
- `snapshot_id`: references `Snapshot`.
- `amount_usd`: decimal (Dinero nuevo inyectado al sistema).
- `direction`: enum (`:deposit`, `:withdrawal`).
- `deleted_at`: timestamp (soft delete).

#### **ExchangeRates** (Cache de Cotizaciones)
Tabla para almacenar cotizaciones y evitar sobrecargar las APIs externas.
- `currency_pair`: string (Ej: "USD_ARS", "BTC_USD").
- `source`: string (Ej: "dolarapi_blue", "binance").
- `rate`: decimal.
- `fetched_at`: timestamp.
- **Índice**: `(currency_pair, source, fetched_at DESC)` para buscar la cotización más reciente.

---

## 4. Lógica de Negocio y Ecuaciones

### 4.1 Normalización de Moneda
- **ConversionService**: Módulo que consulta APIs externas (DolarApi, Binance) al momento de iniciar el Snapshot.
- **ARS -> USD**: Usar cotización "Blue Venta" o "MEP" (Configurable).
- **Cripto -> USD**: Usar precio spot USDT.

### 4.2 El Motor de Cálculo (Snapshot Engine)
Al confirmar el cierre de mes:

1. **Net Worth (NW)**:
   $$NW = \sum Activos - \sum Pasivos$$
   *(Nota: Pasivos Totales incluye cuotas futuras)*

2. **Delta Patrimonial**:
   $$\Delta NW = NW_{actual} - NW_{anterior}$$

3. **Ahorro Real (Savings)**:
   $$Savings = \Delta NW - Yield$$

4. **Rendimiento (Yield)**:
   $$Yield = NW_{actual} - (NW_{anterior} + NetFlows)$$

5. **Gastos de Vida (Implícito)**:
   $$Expenses = Income - Savings$$

---

## 5. Requerimientos Funcionales (UX Flow)

### 5.1 Onboarding & Setup (Snapshot Inicial)
- Registro simple (Email/Pass).
- **Wizard Inicial**: "Vamos a configurar tu mapa financiero".
- Agregar Cuentas Bancarias (ARS/USD) **con saldos iniciales**.
- Agregar Billeteras Cripto/Efectivo **con saldos iniciales**.
- Agregar Tarjetas de Crédito **con deuda actual** (**Crucial**).
- **Resultado**: Se crea el primer Snapshot (mes actual) con `status: :confirmed`. Este será el `NW_anterior` para el próximo cierre.

### 5.2 El "Ritual de Cierre" (Monthly Wizard)
Este es el core loop. No es un formulario largo, es un paso a paso (**LiveView Stepper**).

- **Paso 0**: Fetch de cotizaciones (Automático). Muestra: "Dólar hoy: $1180".
- **Paso 1: Activos**. Lista las cuentas. Input numérico simple para actualizar saldos.
- **Paso 2: Pasivos** (El Momento de la Verdad).
  - Muestra la tarjeta de crédito.
  - **Input A**: "¿Cuánto vence este mes?" (Saldo del resumen).
  - **Input B**: "¿Cuánto suman tus cuotas futuras?" (Instrucción visual: "Mirá el cuadro 'Cuotas a Vencer en el resumen de tu tarjeta'").
  - **Feedback visual**: Muestra el total de deuda en rojo.
- **Paso 3: Flujos**. "¿Pusiste plata nueva en tus inversiones este mes?" (Sí/No -> Monto).
- **Paso 4: Ingresos**. "¿Cuánto ganaste este mes?" (Sueldo + Extras).
- **Paso 5: Resultado**. Muestra la "Tarjeta de Score" (Ahorro vs Rendimiento).

---

## 6. UI/UX Guidelines (Mobile First)

- **Inputs**: Usar `type="tel"` o `inputmode="decimal"` para activar el teclado numérico grande en Android/iOS.
- **Navegación**: Evitar menús hamburguesa complejos. Usar una barra inferior o botones de acción grandes ("Call to Action").
- **Estética**:
  - **Fondo**: `bg-slate-50` (Light) / `bg-zinc-950` (Dark).
  - **Números**: Fuente monoespaciada para cifras (`font-mono`).
  - **Colores semánticos**: Verde esmeralda (Ahorro), Azul índigo (Rendimiento), Rojo rosa (Deuda).

---

## 7. Roadmap MVP (Viernes)

- [ ] **Día 1 (Hoy)**: `mix phx.new`, setup de Base de Datos, Schemas de Ecto y Auth.
- [ ] **Día 2**: Contexto de `Accounts` y `Snapshots`. Integración básica de API de Dólar.
- [ ] **Día 3**: Interfaz LiveView del "Wizard de Cierre" (Lógica de inputs).
- [ ] **Día 4**: Lógica de cálculo (Las ecuaciones) y Pantalla de Resultados.
- [ ] **Día 5**: Deploy en Fly.io y testing en móvil real.

---

> ### Nota para el Desarrollador (Cursor/Humano)
> Priorizar la robustez del cálculo sobre la belleza de la animación. Si el número de Patrimonio Neto está mal calculado, la app pierde su propósito. **Usar `Decimal` para todos los cálculos monetarios, nunca `Float`.**

---

## 8. TODOs Post-MVP
- [ ] Implementar APIs de fallback para cotizaciones (redundancia).
- [ ] Soporte para cotización MEP como alternativa al Blue.
- [ ] Internacionalización (otros países/idiomas).
- [ ] Automatización de cuentas (`is_automated: true`).
