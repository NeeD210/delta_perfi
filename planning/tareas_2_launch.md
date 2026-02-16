# 🚀 Plan Maestro de Ejecución: PerFi Delta

> [!IMPORTANT]
> **Objetivo:** Lanzamiento de MVP funcional y comercializable.  
> **Deadline:** Viernes próximo.  
> **Filosofía:** "Scope Hammer" (Si no es esencial para el cierre de mes, se corta).

---

## 📅 FASE 1: MVP (Prioridad Absoluta)

Todo lo listado aquí debe estar en producción para considerar el proyecto "Lanzado".

### A. Core del Producto (Backend & Lógica)

#### 1. Reparación del "Ritual de Cierre" (Month Close Wizard)
El flujo actual es confuso. Necesitamos una Máquina de Estados sólida.
*   **Estado:** ✅ 100% completado.
*   **Nota:** Stepper implementado en `ClosureWizardLive` con 6 pasos (rates → assets → liabilities → flows → income → result). Commit atómico con `Ecto.Multi` funciona. Todos los inputs usan el JS hook `NumberFormat` para formateo argentino (punto = miles, coma = decimal). El handler de liabilities usa patrón por campo individual (evita stale `phx-value`). Valores retornados en wire format para el hook.

> [!NOTE]
> **Instrucción Técnica para Cursor:**
> "Refactoriza el módulo `MonthCloseLive`. Implementa un patrón de 'Stepper' (Paso a Paso) usando `Phoenix.LiveComponent`.
> 
> **Estados del Wizard:**
> - **FetchPrices:** Llama al `PriceProvider`. Muestra spinner. Confirma cotizaciones (Blue/MEP/BTC).
> - **UpdateBalances:** Itera sobre las cuentas activas. Muestra input numérico (`inputmode='decimal'`).
> - **UpdateLiabilities:** Muestra input de tarjeta. Separa explícitamente: 'Saldo a Pagar' y 'Cuotas Futuras'.
> - **FlowCheck:** Pregunta: '¿Ingresaste dinero nuevo (Ahorro) o retiraste dinero este mes?'. Input de ajuste manual.
> - **Review:** Calcula Delta NW, Savings y Yield en memoria. Muestra la 'Preview'.
> - **Commit:** Usa `Ecto.Multi` para guardar el Snapshot y los Balances en una sola transacción atómica."

#### 2. Lógica del "Estado Cero" (Zero State)
*   **Estado:** ✅ 100% completado.
*   **Nota:** Implementado: el Dashboard detecta si el usuario tiene solo 1 snapshot y muestra un mensaje de bienvenida "Tu línea base está establecida" ocultando las tarjetas de Ahorro y Rendimiento.

> [!NOTE]
> **Instrucción Técnica para Cursor:**
> "En el Dashboard principal (`HomeLive`), detecta si el usuario tiene solo 1 snapshot.
> 
> - **Si `count(snapshots) == 1`**: Oculta las tarjetas de 'Rendimiento' y 'Ahorro'. Muestra un mensaje de bienvenida: 'Tu línea base está establecida. En 30 días verás tu evolución.'
> - **Si `count(snapshots) > 1`**: Muestra la lógica estándar de comparación (Mes Actual vs. Mes Anterior)."

#### 3. Indicador "Runway" (Tiempo de Vida)
*   **Estado:** ✅ 100% completado.
*   **Nota:** Implementado: nueva tarjeta "Libertad Financiera" que calcula meses de vida (Capital Líquido / Gastos Promedio). Incluye colores semánticos (Rojo/Amarillo/Verde).

> [!NOTE]
> **Instrucción Técnica para Cursor:**
> "Agrega una tarjeta en el Dashboard llamada 'Libertad Financiera'.
> 
> **Lógica:** Calcula Gastos Promedio = `(Ingresos - Ahorro)` de los últimos snapshots disponibles.
> 
> **Fórmula:** 
> ```
> Runway = Net_Worth_Liquid / Gastos_Promedio
> ```
> 
> **UI:** Muestra el número en Meses con un color semántico (Rojo < 3 meses, Amarillo < 6, Verde > 6)."

---

### B. Infraestructura & Producción

#### 4. Configuración de Email Transaccional (Resend)
Para recuperar contraseñas y bienvenida.
*   **Estado:** � ~80% completado.
*   **Nota:** Swoosh + Resend adapter configurado. API Key en `.env`. Envío asincrónico implementado (UI instantánea). `FROM_EMAIL` corregido para leerse en runtime. Pendiente: verificar dominio propio para salir del sandbox.

**Tareas Completadas:**
- [x] Crear cuenta en [Resend.com](https://resend.com).
- [x] Generar API Key.
- [x] Migrar secretos a `.env` (seguridad).
- [x] Corregir bug compile-time de `FROM_EMAIL`.
- [x] Implementar envío asincrónico (`Task.start`).

**Tareas Pendientes:**
- [ ] Comprar dominio propio.
- [ ] Verificar dominio en Resend (DNS records: DKIM, SPF, DMARC).
- [ ] Actualizar `FROM_EMAIL` en `.env` con dominio verificado.

> [!NOTE]
> **Instrucción Técnica para Cursor:**
> "Configura el adaptador `swoosh` en `config/prod.exs` para usar la API de Resend.
> 
> - Usa `System.get_env("RESEND_API_KEY")`.
> - Actualiza el `UserNotifier` para que el 'Sender' sea `hola@tu-dominio.com` y no `example.com`."

#### 5. Deploy en Fly.io
*   **Estado:** � 0% completado.
*   **Nota:** No hay `fly.toml` ni `Dockerfile` en el proyecto. No se ha ejecutado `fly launch`. Todo está por hacer.

**Tareas Manuales:**
- [ ] Instalar `flyctl`.
- [ ] Ejecutar `fly launch`.
- [ ] Vincular base de datos Postgres (Hobby Dev).
- [ ] Setear secretos: `fly secrets set SECRET_KEY_BASE=... RESEND_API_KEY=<ver .env>`

---

### C. Estrategia de Marketing & Growth (El Funnel)

#### 6. Landing Page (Integrada en Phoenix)
La "Home" de la web para no usuarios.
*   **Estado:** 🔴 0% completado.
*   **Nota:** No hay `PageController` ni landing page. La ruta raíz redirige al login/dashboard. Es una feature completamente nueva.

> [!NOTE]
> **Instrucción Técnica para Cursor:**
> "Modifica `PageController.home` para que sea una Landing Page de conversión.
> 
> - **Hero Section:** 'Tus finanzas, sin la culpa. Deja de anotar gastos. Empieza a medir riqueza.'
> - **CTA Principal:** 'Empezar Diagnóstico Gratis' (Link a Typeform/Tally).
> - **CTA Secundario:** 'Ya tengo cuenta' (Link a `/log_in`).
> - **Footer:** Links legales mínimos."

#### 7. El "Hook" de Entrada (Typeform/Tally)
No programes esto en la app todavía. Usa herramientas No-Code.
*   **Herramienta:** [Tally.so](https://tally.so) (Gratis y estético).
*   **Estado:** 🔴 0% completado.
*   **Nota:** Trabajo externo a la app. Formulario de Tally no creado aún.

**Estructura del Formulario:**
- [ ] "¿Sabés exactamente cuánto subió tu patrimonio el mes pasado?" (Sí/No).
- [ ] "¿Tenés deudas en tarjeta de crédito?" (Sí/No).
- [ ] "¿En qué moneda ahorrás?" (Pesos/Dólar/Cripto).
- [ ] **Final:** "Tu perfil es [Inversor Caótico / Ahorrador Ciego]. Necesitas orden. Crea tu cuenta en PerFi Delta para ver tu número real." -> Redirección automática a `/users/register`.

#### 8. Setup de Redes Sociales (Organic Growth)
*   **Estado:** 🔴 0% completado.
*   **Nota:** Trabajo externo. Cuentas de Instagram/TikTok no creadas.

- [ ] **Instagram/TikTok:** Crea la cuenta `@PerfiApp`.
- [ ] **Content 1:** Video de pantalla grabando el "Cierre de Mes" en 30 segundos. Texto: "Lo único que hago el día 1 del mes".
- [ ] **Content 2:** Foto de un Excel complejo tachado vs. la pantalla limpia de PerFi.

---

## 📊 Resumen de Progreso FASE 1

| # | Tarea | % | Estado |
|---|-------|---|--------|
| 1 | Closure Wizard | 100% | ✅ Completado |
| 2 | Zero State | 100% | ✅ Completado |
| 3 | Runway | 100% | ✅ Completado |
| 4 | Email (Resend) | 80% | 🟢 Falta dominio |
| 5 | Deploy (Fly.io) | 0% | 🔴 Sin empezar |
| 6 | Landing Page | 0% | 🔴 Sin empezar |
| 7 | Tally Form | 0% | 🔴 Externo |
| 8 | Redes Sociales | 0% | 🔴 Externo |

**Progreso global estimado: ~60%** (peso ponderado por prioridad)

---

## 🔮 FASE 2: POST-MVP (Roadmap V2)

Tareas para abordar SOLO después de tener usuarios activos.

### Mejoras de Producto
- [ ] **Snapshots Flexibles y Quick Snapshots:** (Propuesta V2) Permitir múltiples snapshots por mes, comparaciones personalizadas (1M, 6M, 1A) y snapshots parciales. Ver detalle técnico en `mejora_snapshots.md`.
- [ ] **Edición Histórica:** Permitir corregir un error en un snapshot de hace 3 meses (requiere recalcular todos los deltas posteriores).
- [ ] **Selector de Dólar:** Toggle en el perfil para elegir si valúo mis USD a "Blue" o "MEP" (ahora está hardcodeado a Blue).
- [ ] **Soporte Multi-Activo Real:** Integrar API de Yahoo Finance para acciones específicas (AAPL, TSLA) más allá de los manuales.

### Growth Automatizado
- [ ] **Social Login (Google/Apple):** Implementar login con Ueberauth para reducir fricción de registro. Ver guía completa en `social_login.md`.
- [ ] **Referral System:** "Invita a un amigo y gana 1 mes de Premium" (cuando exista Premium).
- [ ] **Email Drips:** Secuencia automatizada de educación financiera ("Día 3: Por qué tu tarjeta te miente", "Día 10: Cómo leer tu rendimiento").

---

## 📝 Checklist de Validación para el Viernes

- [ ] ¿Puedo registrarme con un email real?
- [ ] ¿Puedo cargar mis cuentas iniciales (Banco + Binance + Tarjeta)?
- [ ] ¿El dashboard "Estado Cero" se ve bien?
- [ ] ¿Puedo ejecutar un "Cierre de Mes" simulado y ver cómo cambia mi patrimonio?
- [ ] ¿El cálculo de "Ahorro vs Rendimiento" tiene sentido matemático?
- [ ] ¿La Landing Page explica la propuesta de valor en 3 segundos?

> [!TIP]
> **Si las 6 respuestas son SÍ, lanzamos.**
