# Resumen Ejecutivo: PerFi Delta

**PerFi Delta** es una aplicación de finanzas personales enfocada en el **Patrimonio Neto (Net Worth)** y la filosofía de "Finanzas Zen". A diferencia de los expense trackers tradicionales, no te pide categorizar cada café, sino que mide tu enriquecimiento real mes a mes mediante la diferencia patrimonial.

## Filosofía Core
- **Foco**: "No me digas en qué gasté, dime cuánto me enriquecí".
- **Métrica Norte**: `Delta NW` (Variación del Patrimonio).
- **Desagregación**: Separa el crecimiento en **Ahorro Real** (lo que guardaste de tu ingreso) y **Rendimiento** (lo que generaron tus inversiones).

## Funcionalidades Principales

### 1. Onboarding "Zen"
Un wizard de 8 pasos diseñado para configurar el mapa financiero inicial sin fricción.
- **Personalizable**: Pregunta si tenés inversiones o deudas para adaptar los pasos siguientes.
- **Presets de Inversión**: Selección rápida de activos comunes (Bitcoin, Ethereum, USDT, S&P 500, FCI Money Market).
- **Carga de Saldos**: Detección de moneda y conversión automática de ARS a USD usando la cotización del Dólar Blue en tiempo real.
- **Resultado Inmediato**: Al finalizar, muestra el primer cálculo de Patrimonio Neto.

### 2. El Ritual de Cierre Mensual
El corazón de la app. Un proceso guiado de 6 pasos para cerrar el mes:
1.  **Cotizaciones**: Fetch automático de Dólar Blue y MEP.
2.  **Activos**: Actualización rápida de saldos.
3.  **Pasivos**: Carga diferenciada de "Saldo a pagar este mes" vs "Cuotas futuras" (para no distorsionar el cash flow).
4.  **Flujos de Inversión**: Registro de aportes o retiros de capital (clave para calcular el rendimiento real y no confundirlo con ahorro).
5.  **Ingresos**: Carga del ingreso total del mes.
6.  **Resultado**: Cálculo automático de:
    -   **Net Worth**: Activos - Pasivos.
    -   **Savings**: Cuánto de tu ingreso no se gastó.
    -   **Yield**: Cuánto dinero generó tu dinero.
    -   **Expenses**: Gasto de vida (deducido por diferencia).

### 3. Gestión de Cuentas
- **Tipos soportados**:
    -   🟢 **Líquidas**: Bancos, Efectivo, Billeteras.
    -   🔵 **Inversiones**: Crypto (BTC, ETH, SOL, USDT), Bonos, Acciones.
    -   🔴 **Pasivos**: Tarjetas de Crédito, Préstamos.
- **Multi-moneda**: Soporte nativo para ARS, USD y Cryptos. Todo se normaliza a USD para los reportes.
- **Filtros rápidos**: Toggle visual entre tipos de cuenta en el listado.

### 4. Historial y Analytics
- **Evolución**: Gráfico de barras interactivo con la evolución del Patrimonio Neto (últimos 12 meses).
- **Snapshots Detallados**: Posibilidad de entrar a cualquier cierre pasado para ver el detalle de cuentas, flujos y métricas de ese momento exacto.

## Stack Tecnológico y UX
- **Backend**: Elixir & Phoenix LiveView (Rendimiento y tiempo real).
- **Frontend**: TailwindCSS 4 + DaisyUI 5.
- **Diseño**: "Glassmorphism" con estética premium/dark mode.
- **UX Mobile-First**: Inputs numéricos optimizados, navegación inferior, feedback háptico visual (animaciones).

## Estado Actual vs Referencia Anterior
Respecto a la documentación previa (`SUMMARY.md`), la app ha evolucionado incorporando:
- **Presets de Inversión** en el onboarding.
- **Distinción de Deuda**: Separación lógica entre deuda corriente y futura en el wizard.
- **UI Refinada**: Implementación completa de estilos Glass/Zen y gráficos de evolución.

---

## Pendientes vs PRD (Gap Analysis)

Basado en la revisión del `PRD.md` y el estado actual del código:

1.  **Configuración de Moneda de Referencia**:
    -   *Estado PRD*: "Cotización por defecto: Dólar Blue (configurable a MEP en futuras versiones)".
    -   *Estado Actual*: Se obtienen y guardan ambas (Blue y MEP), pero el sistema usa **exclusivamente Blue** para las conversiones de ARS a USD. No hay selector UI para cambiar esto todavía.

2.  **Validaciones de Integridad**:
    -   *Estado PRD*: Prioridad en "robustez del cálculo".
    -   *Estado Actual*: Las validaciones son básicas (frontend). Faltan restricciones más fuertes en el backend (Contexto) para asegurar que no se creen snapshots inconsistentes si el frontend falla.

3.  **Tests Automatizados**:
    -   *Estado PRD*: Nota crítica sobre "robustez del cálculo".
    -   *Estado Actual*: Marcado como pendiente en `SUMMARY.md`. El motor de cálculo (`Finance.calculate_snapshot_values`) es crítico y debería tener cobertura de tests unitarios exhaustiva.

4.  **Automatización (Post-MVP)**:
    -   *Estado PRD*: `is_automated: true` para cuentas.
    -   *Estado Actual*: No implementado (tal como se planeó para el MVP).
