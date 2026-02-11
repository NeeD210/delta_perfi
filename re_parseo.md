# Refactorización del Parseo y Formateo de Números

## Problema Actual

### Síntomas
- Los valores de tarjetas se resetean a 0 de forma aleatoria al ingresar datos
- Inconsistencia en el formato de entrada/salida entre módulos
- Código duplicado en múltiples archivos

### Causa Raíz
Existen **múltiples implementaciones** de `parse_decimal` y `format_decimal` dispersas en:
- `onboarding_live.ex`
- `closure_wizard_live.ex`
- `history_live.ex`
- `accounts_live.ex`

Cada una tiene ligeras variaciones que causan inconsistencias al convertir entre:
- Formato usuario: `1.400,50` (separador de miles = `.`, decimal = `,`)
- Formato Elixir/Decimal: `1400.50`

---

## Solución Propuesta

### 1. Crear módulo centralizado

```elixir
# lib/perfi_delta_web/helpers/number_helpers.ex

defmodule PerfiDeltaWeb.Helpers.NumberHelpers do
  @moduledoc """
  Funciones centralizadas para parseo y formateo de números monetarios.
  Formato argentino: puntos = miles, coma = decimal.
  """

  @doc """
  Parsea un string a Decimal.
  Acepta formatos: "1.400,50", "1400.50", "1400", ""
  """
  def parse_currency(nil), do: Decimal.new(0)
  def parse_currency(""), do: Decimal.new(0)
  def parse_currency(str) when is_binary(str) do
    # ... lógica robusta
  end

  @doc """
  Formatea un Decimal para display.
  Opciones: :integer (sin decimales), :currency (2 decimales)
  """
  def format_currency(decimal, opts \\ [])
  
  @doc """
  Formato "inteligente" para valores mixtos (cripto vs fiat).
  """
  def format_smart(decimal)
end
```

### 2. Agregar test suite

```elixir
# test/perfi_delta_web/helpers/number_helpers_test.exs

defmodule PerfiDeltaWeb.Helpers.NumberHelpersTest do
  use ExUnit.Case

  describe "parse_currency/1" do
    test "parsea formato argentino con miles y decimales"
    test "parsea formato decimal directo"  
    test "maneja strings vacíos y nil"
    test "no falla con input inválido"
  end

  describe "format_currency/2" do
    test "formatea con separadores de miles"
    test "redondea a enteros cuando corresponde"
  end
end
```

### 3. Reemplazar en todos los módulos

| Archivo | Función a reemplazar |
|---------|---------------------|
| `onboarding_live.ex` | `parse_decimal/1`, formateo inline |
| `closure_wizard_live.ex` | `parse_decimal/1`, `format_decimal/1` |
| `history_live.ex` | `format_decimal/1` |
| `accounts_live.ex` | `format_currency/1`, `add_thousands_separator/1` |

---

## Casos de Prueba Requeridos

### Parseo
| Input | Expected Output |
|-------|-----------------|
| `"1.400,50"` | `Decimal.new("1400.50")` |
| `"1400.50"` | `Decimal.new("1400.50")` |
| `"1400"` | `Decimal.new("1400")` |
| `""` | `Decimal.new("0")` |
| `nil` | `Decimal.new("0")` |
| `"abc"` | `Decimal.new("0")` |
| `"0,00012"` | `Decimal.new("0.00012")` |

### Formateo
| Input | Expected Output |
|-------|-----------------|
| `Decimal.new("1400.5")` | `"1.400"` (integer) |
| `Decimal.new("0.00012")` | `"0,00012"` (smart) |
| `nil` | `"0"` |

---

## Plan de Implementación

1. [ ] Crear `number_helpers.ex` con funciones base
2. [ ] Crear `number_helpers_test.exs` con casos de prueba
3. [ ] Ejecutar tests y ajustar implementación
4. [ ] Importar helper en `onboarding_live.ex` y reemplazar
5. [ ] Importar helper en `closure_wizard_live.ex` y reemplazar
6. [ ] Importar helper en otros módulos afectados
7. [ ] Verificar que no hay regresiones en la UI
