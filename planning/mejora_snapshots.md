# Plan de Implementación: Mejora del Sistema de Snapshots

## Objetivo

Evolucionar el sistema de snapshots de "1 foto mensual fija" a un modelo flexible donde el usuario pueda:

1. Crear snapshots cuando quiera (sin límite de 1 por mes)
2. Elegir qué secciones completar en cada snapshot (Quick Snapshot)
3. Comparar contra diferentes timeframes (1M, 6M, 1A, personalizado)
4. Editar y eliminar snapshots existentes
5. Ver indicadores prorrateados a equivalente mensual

---

## User Review Required

> [!IMPORTANT]
> **Decisión de diseño: ¿Qué pasa con `month` y `year`?**
> Se propone **conservar** los campos `month` y `year` (para compatibilidad y agrupación rápida) pero **agregar** `snapshot_date` como campo principal. Se **elimina** el unique constraint `(user_id, month, year)`. El campo `month`/`year` se derivará automáticamente del `snapshot_date`.

> [!WARNING]
> **Snapshots nuevos vs. existentes**: Los snapshots ya confirmados en producción no tienen `snapshot_date` ni `snapshot_type`. La migración les asignará una fecha calculada como `{year}-{month}-15` y tipo `:full`.

> [!IMPORTANT]
> **Edición de snapshots**: Solo se permite editar/eliminar si el snapshot **no es el más antiguo** (el Snapshot₀ del onboarding es inmutable) y si no hay snapshots posteriores que dependan de él para cálculos. Alternativamente, si se edita, se recalcula en cascada. **¿Preferís recalcular en cascada o limitar la edición solo al último snapshot?**

---

## Propuesta de Cambios

### Fase 1: Schema y Migración

#### [MODIFY] [snapshot.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/lib/perfi_delta/finance/snapshot.ex)

Agregar campos nuevos al schema:

```diff
 schema "snapshots" do
   field :month, :integer
   field :year, :integer
+  field :snapshot_date, :date
   field :status, Ecto.Enum, values: @statuses, default: :draft
+  field :snapshot_type, Ecto.Enum, values: [:full, :quick], default: :full
+  field :included_sections, {:array, :string}, default: ["assets", "liabilities", "flows", "income"]

   # Campos calculados/ingresados
   field :total_income_usd, :decimal
   ...
 end
```

- `snapshot_date`: Fecha del snapshot (reemplaza a `month`/`year` como dato primario)
- `snapshot_type`: `:full` (wizard completo) o `:quick` (solo secciones seleccionadas)
- `included_sections`: Lista de secciones completadas (ej: `["assets", "liabilities"]`)

Eliminar el unique constraint en el changeset. `month`/`year` se auto-derivan de `snapshot_date`.

#### [NEW] Migración: `add_snapshot_date_and_type.exs`

```elixir
alter table(:snapshots) do
  add :snapshot_date, :date
  add :snapshot_type, :string, default: "full"
  add :included_sections, {:array, :string}, default: ["assets", "liabilities", "flows", "income"]
end

# Calcular snapshot_date para snapshots existentes
execute """
  UPDATE snapshots
  SET snapshot_date = make_date(year, month, 15)
  WHERE snapshot_date IS NULL
"""

# Eliminar el unique constraint viejo
drop_if_exists unique_index(:snapshots, [:user_id, :month, :year])
```

---

### Fase 2: Finance Context

#### [MODIFY] [finance.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/lib/perfi_delta/finance.ex)

**Funciones a modificar:**

1. **`get_or_create_current_snapshot/1`** → Renombrar a `create_new_snapshot/1`
   - Ya no busca "el snapshot del mes actual". Siempre crea un draft nuevo con `snapshot_date: Date.utc_today()`.

2. **`get_previous_snapshot/1`** → Cambiar lógica
   - Actual: busca `month - 1` aritméticamente
   - Nuevo: busca el último snapshot `confirmed` con `snapshot_date < snapshot.snapshot_date` ordenado por `snapshot_date DESC`

3. **`get_latest_confirmed_snapshot/1`** → Ordenar por `snapshot_date DESC` en vez de `year DESC, month DESC`

4. **`list_confirmed_snapshots/1`** → Idem, ordenar por `snapshot_date DESC`

**Funciones nuevas:**

5. **`get_snapshot_for_comparison/3`** — Busca el snapshot para comparar según timeframe:
   ```elixir
   def get_snapshot_for_comparison(user_id, :one_month, reference_date)
   def get_snapshot_for_comparison(user_id, :six_months, reference_date)
   def get_snapshot_for_comparison(user_id, :one_year, reference_date)
   def get_snapshot_for_comparison(user_id, {:custom, snapshot_id}, _reference_date)
   ```
   Para timeframes relativos, busca el snapshot confirmado más cercano a la fecha target.

6. **`calculate_prorated_values/3`** — Prorrateo mensual:
   ```elixir
   def calculate_prorated_values(current_snapshot, comparison_snapshot, values) do
     days = Date.diff(current_snapshot.snapshot_date, comparison_snapshot.snapshot_date)
     factor = Decimal.div(Decimal.new(30), Decimal.new(max(days, 1)))
     # Multiplica savings, yield, expenses por factor
   end
   ```

7. **`update_confirmed_snapshot/2`** — Permite editar un snapshot confirmado (reabriéndolo como draft, o actualizando directamente).

8. **`delete_snapshot/1`** — Soft-delete de un snapshot y sus relaciones (balances, flows, liability_details).

9. **`recalculate_dependent_snapshots/1`** — Si se edita un snapshot que no es el último, recalcular los indicadores de los snapshots posteriores que usan su `NW` como referencia.

---

### Fase 3: ClosureWizardLive (Pantalla de selección + Quick Snapshot)

#### [MODIFY] [closure_wizard_live.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/lib/perfi_delta_web/live/closure_wizard_live.ex)

**Cambio principal: Pantalla de configuración antes del wizard**

Agregar un paso previo (`:setup`) donde el usuario elige:
- **Tipo de snapshot**: Completo o Rápido
- **Secciones a incluir** (solo si es Rápido): checkboxes para Activos, Pasivos, Flujos, Ingresos

```diff
-  @steps [:rates, :assets, :liabilities, :flows, :income, :result]
+  # Los steps se calculan dinámicamente según las secciones seleccionadas
+  @all_steps [:rates, :assets, :liabilities, :flows, :income, :result]
```

**Cambios en `mount/3`:**
```diff
-    {:ok, snapshot} = Finance.get_or_create_current_snapshot(user_id)
+    {:ok, snapshot} = Finance.create_new_snapshot(user_id)
```

El wizard ahora empieza en el paso `:setup` y, según la selección del usuario, arma la lista de steps dinámicamente:

- Si `:quick` + solo `["assets"]` → steps = `[:rates, :assets, :result]`
- Si `:full` → steps = `[:rates, :assets, :liabilities, :flows, :income, :result]`

**En `confirm_closure`**: Guardar `snapshot_type` e `included_sections` en el snapshot.

**Textos UX**: Cambiar las referencias a "mes" por textos genéricos:
- "Cierre de Mes" → "Nuevo Snapshot"
- "este mes" → "desde tu último snapshot"
- "Tu Score del Mes" → "Tu Score"

---

### Fase 4: DashboardLive (Timeframe Selector + Prorrateo)

#### [MODIFY] [dashboard_live.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/lib/perfi_delta_web/live/dashboard_live.ex)

**Nuevo assign: `timeframe`**

```elixir
|> assign(:timeframe, :latest)       # Default: compara con snapshot anterior directo
|> assign(:comparison_snapshot, nil)  # El snapshot contra el que se compara
|> assign(:prorated_values, nil)      # Valores prorrateados a mensual
```

**Nuevo componente: Timeframe Selector**

Un toggle/pill con opciones: `1M | 6M | 1A | Personalizado`

```elixir
def handle_event("change_timeframe", %{"timeframe" => tf}, socket) do
  # Buscar snapshot de comparación según el timeframe
  comparison = Finance.get_snapshot_for_comparison(user_id, parse_timeframe(tf), latest.snapshot_date)
  # Recalcular indicadores: delta entre latest y comparison
  # Calcular prorrateo mensual
end
```

**UI: Mostrar período y prorrateo**

```
Último snapshot: 13 Feb 2026
vs. snapshot del 15 Ene 2026 (29 días)

Ahorro Real: +US$ 450         ← valor absoluto del período
Equiv. mensual: +US$ 466/mes  ← prorrateado a 30 días
```

**CTA**: Cambiar `should_show_closure_cta?/1`:
```diff
-  defp should_show_closure_cta?(snapshot) do
-    now = DateTime.now!("America/Argentina/Buenos_Aires")
-    snapshot.month != now.month or snapshot.year != now.year
-  end
+  # Siempre mostrar - el usuario puede hacer snapshots cuando quiera
+  defp should_show_closure_cta?(_snapshot), do: true
```

Texto del CTA: "Nuevo Snapshot" en vez de "Cierre de {Mes}".

---

### Fase 5: HistoryLive (Edición y Eliminación)

#### [MODIFY] [history_live.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/lib/perfi_delta_web/live/history_live.ex)

**Cambios en la lista de snapshots:**
- Mostrar `snapshot_date` formateada (ej: "13 Feb 2026") en vez de solo "Febrero 2026"
- Mostrar badge de tipo: `Full` o `Quick`
- Mostrar días transcurridos entre snapshots consecutivos

**Nuevos event handlers:**

1. **`edit_snapshot`**: Redirige al `ClosureWizardLive` pasando `snapshot_id` como parámetro de URL (`/cierre?edit=SNAPSHOT_ID`). El wizard carga los datos existentes para edición.

2. **`delete_snapshot`**: Modal de confirmación → llama a `Finance.delete_snapshot/1`. Si hay snapshots posteriores, muestra advertencia de que se recalcularán.

**Modal de detalle**: Agregar botones de "Editar" y "Eliminar" en la parte inferior del modal.

---

### Fase 6: ClosureWizardLive (Modo Edición)

#### [MODIFY] [closure_wizard_live.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/lib/perfi_delta_web/live/closure_wizard_live.ex)

**En `mount/3`**: Detectar si viene un `?edit=SNAPSHOT_ID` en los parámetros:

```elixir
def mount(params, _session, socket) do
  case params["edit"] do
    nil -> 
      # Modo creación: crear draft nuevo
      {:ok, snapshot} = Finance.create_new_snapshot(user_id)
      ...
    snapshot_id ->
      # Modo edición: cargar snapshot existente con sus datos
      snapshot = Finance.get_snapshot_with_details!(snapshot_id)
      balances = load_balances_from_snapshot(snapshot)
      flows = snapshot.investment_flows
      ...
  end
end
```

**En `confirm_closure`**: Si es edición, actualizar snapshot existente en vez de crear uno nuevo. Si hay snapshots posteriores, disparar recalculation en cascada.

---

### Resumen de archivos a modificar

| Archivo | Tipo | Cambios principales |
|---------|------|---------------------|
| [snapshot.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/lib/perfi_delta/finance/snapshot.ex) | MODIFY | +3 campos: `snapshot_date`, `snapshot_type`, `included_sections` |
| Nueva migración | NEW | Agregar columnas, backfill, eliminar constraint |
| [finance.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/lib/perfi_delta/finance.ex) | MODIFY | Refactor 4 funciones + agregar 5 funciones nuevas |
| [closure_wizard_live.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/lib/perfi_delta_web/live/closure_wizard_live.ex) | MODIFY | Paso `:setup`, steps dinámicos, modo edición |
| [dashboard_live.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/lib/perfi_delta_web/live/dashboard_live.ex) | MODIFY | Timeframe selector, prorrateo, textos actualizados |
| [history_live.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/lib/perfi_delta_web/live/history_live.ex) | MODIFY | Botones editar/eliminar, mostrar fecha completa y badge de tipo |
| [router.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/lib/perfi_delta_web/router.ex) | MODIFY | Mínimo: el wizard ya acepta `params`, no necesita nueva ruta |
| [finance_test.exs](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/test/perfi_delta/finance_test.exs) | MODIFY | Tests nuevos para las funciones de comparación y prorrateo |
| [finance_fixtures.ex](file:///c:/Users/facun/OneDrive/Escritorio/programming/PerFi_Delta/perfi_delta/test/support/fixtures/finance_fixtures.ex) | MODIFY | Actualizar fixture para incluir `snapshot_date` |

---

## Verification Plan

### Tests automatizados

Agregar tests en `test/perfi_delta/finance_test.exs`:

1. **Test: crear múltiples snapshots en el mismo mes** — Verificar que ya no hay constraint violation
2. **Test: `get_previous_snapshot` por fecha** — Crear 3 snapshots con diferentes `snapshot_date`, verificar que retorna el inmediato anterior por fecha
3. **Test: `get_snapshot_for_comparison` con timeframes** — Crear snapshots a 30, 180 y 365 días, verificar que cada timeframe devuelve el correcto
4. **Test: `calculate_prorated_values`** — Crear un snapshot con $300 de ahorro en 15 días → prorrateo mensual = $600
5. **Test: `delete_snapshot`** — Verificar soft delete y que no aparece en `list_confirmed_snapshots`
6. **Test: editar snapshot y recalcular** — Editar NW de un snapshot intermedio y verificar que Yield/Savings del siguiente se recalculan

**Comando para correr los tests:**
```powershell
cd c:\Users\facun\OneDrive\Escritorio\programming\PerFi_Delta\perfi_delta
mix test test/perfi_delta/finance_test.exs
```

### Verificación manual (requiere el server corriendo)

**Comando para iniciar el server:**
```powershell
cd c:\Users\facun\OneDrive\Escritorio\programming\PerFi_Delta\perfi_delta
mix phx.server
```

1. **Crear snapshot rápido**: Ir a `/cierre`, seleccionar "Snapshot Rápido", marcar solo "Activos", completar, confirmar → verificar que se guarda con `snapshot_type: :quick` y solo incluye balances de activos.

2. **Crear segundo snapshot en el mismo mes**: Volver al dashboard, presionar "Nuevo Snapshot", completar → verificar que se crea sin error.

3. **Timeframe selector**: En el dashboard, cambiar entre 1M/6M/1A → verificar que los indicadores cambian según el snapshot de comparación.

4. **Editar snapshot**: Ir a `/historial`, abrir un snapshot, presionar "Editar", cambiar un saldo, confirmar → verificar que los valores se actualizaron.

5. **Eliminar snapshot**: Ir a `/historial`, eliminar un snapshot intermedio → verificar que los indicadores de snapshots posteriores se recalculan.

> [!TIP]
> Sugiero que vos hagas las pruebas manuales de UX en el celular, ya que la app está diseñada mobile-first. Yo puedo correr los tests automatizados y verificar visualmente en el browser.

---

## Orden de implementación sugerido

1. **Fase 1**: Migración + Schema (base para todo lo demás)
2. **Fase 2**: Finance context (funciones nuevas + refactor)
3. **Fase 3**: ClosureWizardLive (setup screen + quick snapshot)
4. **Fase 4**: DashboardLive (timeframe selector + prorrateo)
5. **Fase 5**: HistoryLive (editar/eliminar)
6. **Fase 6**: ClosureWizardLive modo edición
7. **Tests** (incremental, junto a cada fase)
