This file contains the preferences for the agent.

## Preferences
- Don't ask for reviews on the planning. Execute. I will review it after it's working.
- After modifying any file, apply the changes, compile the app and run the tests. If there are any errors, fix them.
- When coding, the project must be running. If it isn't then the agent should start it proactively.
- **Restarting the server**: Before running `mix phx.server`, always kill the process occupying port 4000 first to avoid `:eaddrinuse`. Use:
  ```powershell
  $p = Get-NetTCPConnection -LocalPort 4000 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique; if ($p) { $p | ForEach-Object { Stop-Process -Id $_ -Force } }; Start-Sleep -Seconds 3
  ```

## Learnings from Workflow

### LiveView State Management
- Cuando se usan eventos `phx-blur` con múltiples campos relacionados (ej: "consumo actual" y "cuotas futuras" en deudas), **NO pasar valores estáticos via `phx-value-*`** porque quedan obsoletos al re-render. En cambio, pasar solo el identificador del campo que cambió y obtener el valor desde `socket.assigns`.
- El handler debe **mergear** el nuevo valor con el estado existente, no reemplazarlo completo.

### Formato de Números (Argentina)
- **Arquitectura**: El JS hook `NumberFormat` maneja TODO el formateo visual. El server NUNCA recibe strings formateados.
- **Display**: punto (`.`) = miles, coma (`,`) = decimal. El punto está BLOQUEADO como input del usuario.
- **Wire format**: El hook envía números limpios al server (`"1400"`, `"1400.50"`). `parse_currency` solo hace `Decimal.new`.
- **Flujo**: User escribe `1400` → JS muestra `1.400` → blur envía `"1400"` al server → `Decimal.new("1400")`.
- **NUNCA** definir helpers locales (`add_thousands_separator`, `format_currency`, `parse_decimal`) en LiveViews. Usar `import PerfiDeltaWeb.Helpers.NumberHelpers, only: [...]`.

### Tests
- Mantener un test suite mínimo y enfocado (~10 tests fundamentales) en español.
- Los tests de onboarding deben seleccionar explícitamente las preferencias (inversiones/deudas) para garantizar que el wizard pase por todos los pasos.
- Asegurar que `mount` cargue datos existentes (cuentas) para que los tests no dependan del estado inicial vacío.
