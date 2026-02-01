---
name: phoenix-server-restart
description: Restart the Phoenix development server. Use automatically after adding dependencies (mix.exs changes), modifying config files, fixing compilation errors, or when the user asks to restart/reiniciar the server.
---

# Phoenix Server Restart

## When to Apply (Auto-Trigger)

Apply this skill automatically when:
- Dependencies are added/changed in `mix.exs`
- Configuration files are modified (`config/*.exs`)
- Compilation errors are fixed that require a fresh server start
- User explicitly asks to restart/reiniciar the server
- Server crashes and needs to be restarted

## Restart Procedure

### Step 1: Check for existing server on port 4000

```powershell
Get-NetTCPConnection -LocalPort 4000 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

This command safely kills any process using port 4000. Errors about missing processes are expected and safe to ignore.

### Step 2: Start the Phoenix server

```bash
mix phx.server
```

Run with:
- `working_directory`: `perfi_delta` folder (where `mix.exs` lives)
- `block_until_ms`: 0 (runs in background as a long-running process)
- `required_permissions`: `["network"]`

### Step 3: Verify startup

Wait 3-5 seconds, then read the terminal output to confirm:
- ✅ Success: `[info] Running PerfiDeltaWeb.Endpoint with Bandit ... at 127.0.0.1:4000`
- ❌ Port in use: `port 4000 already in use` → Go back to Step 1
- ❌ Compilation error: Fix the error and retry

## After Dependencies Change

If `mix.exs` was modified, run `mix deps.get` before restarting:

```bash
mix deps.get
```

Run with `required_permissions: ["network"]` to allow package downloads.

## Quick Reference

| Scenario | Commands |
|----------|----------|
| Simple restart | Kill port 4000 → `mix phx.server` |
| After adding deps | `mix deps.get` → Kill port 4000 → `mix phx.server` |
| After config change | Kill port 4000 → `mix phx.server` |
