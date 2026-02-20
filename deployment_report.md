# Fly.io Deployment Debug Report

## Executive Summary
The deployment to Fly.io failed due to a combination of configuration issues involving Docker command parsing, script permissions/line-endings on Windows, and LiteFS lease strategy negotiation. All issues have been addressed in the configuration files.

## Detailed Issues & Fixes

### 1. Docker CMD & Entrypoint Conflict ("Usage" Error)
**The Issue:**
The application crashed immediately upon startup, printing the generic "Usage" help text for the release script.
**Root Cause:**
In the `Dockerfile`, the `CMD` was defined as:
```dockerfile
CMD ["sh", "-c", "/app/bin/perfi_delta eval ... && /app/bin/perfi_delta start"]
```
When using `ENTRYPOINT ["litefs", "mount", "--"]`, LiteFS passes the `CMD` arguments to the mounted process. The complex string interpolation with `sh -c` was not being parsed correctly when passed through the LiteFS entrypoint, causing the underlying `perfi_delta` script to receive malformed arguments.

**The Fix:**
We created a dedicated executable shell script `rel/overlays/bin/server` to handle the command chaining (migration + start) explicitly.
```bash
#!/bin/sh
./perfi_delta eval PerfiDelta.Release.migrate
exec ./perfi_delta start
```
The Dockerfile `CMD` was simplified to just `["/app/bin/server"]`.

### 2. Script Permissions & Line Endings (Windows Compatibility)
**The Issue:**
After switching to the script, the deployment failed with:
`fork/exec /app/bin/server: no such file or directory` or permission denied errors.
**Root Cause:**
1.  **Line Endings (CRLF):** The `server` script was created on Windows, which uses Carriage Return + Line Feed (`\r\n`). Linux environments (like the Fly.io container) interpret the `\r` as part of the filename or interpreter path (e.g., `/bin/sh^M`), causing the "no such file" error.
2.  **Permissions:** The script file lost its `executable` (+x) bit when moving between Windows and the Linux build environment.

**The Fix:**
We modified the `Dockerfile` to explicitly fix these issues during the build process:
```dockerfile
COPY rel rel
RUN chmod +x rel/overlays/bin/server && sed -i 's/\r$//' rel/overlays/bin/server
```

### 3. LiteFS Lease Strategy (Consul vs Static)
**The Issue:**
The application effectively started but failed to become reachable or "healthy". Logs showed repeated connection refused errors when trying to contact Consul.
**Root Cause:**
The `consul` lease strategy in `litefs.yml` requires an active Consul cluster or the internal Fly.io Consul service to be accessible. In some single-node configurations or specific Fly.io environments, this service might not be immediately available or configured as expected, leading to a boot loop.
**The Fix:**
We reverted `litefs.yml` to use the `static` lease strategy.
```yaml
lease:
  type: "static"
  candidate: true
  promote: true
```
This is ideal for single-node deployments as it elects itself as the primary leader without external dependencies.

## Final Configuration Status
- **Dockerfile:** Updated to clean script headers and permissions.
- **rel/overlays/bin/server:** Created to orchestrate startup.
- **litefs.yml:** Configured for single-node stability (`static` lease).
- **fly.toml:** Confirmed Internal Port (8080) maps to App Port (8081).

## Recommendations
The codebase is now correctly configured to deploy from a Windows environment to Fly.io. You can proceed to deploy using:
`fly deploy --remote-only`
