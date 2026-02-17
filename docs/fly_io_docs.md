# Arquitectura y despliegue en el borde: Reporte técnico sobre el ecosistema Fly.io

La evolución de la computación en la nube ha transitado desde centros de datos centralizados hacia arquitecturas distribuidas en el borde (*edge computing*), donde la latencia y la proximidad al usuario final definen el éxito de una aplicación. **Fly.io** se ha posicionado como un actor disruptivo en este espacio, ofreciendo una plataforma que permite ejecutar aplicaciones en micro-máquinas virtuales (microVMs) basadas en Firecracker en más de 35 regiones globales.

El presente reporte analiza de manera exhaustiva el flujo de trabajo, las capacidades de gestión mediante su interfaz de línea de comandos (CLI), las disparidades funcionales respecto a su panel de control web, y los desafíos técnicos críticos en el alojamiento de servicios y la migración de bases de datos.

---

## 1. Arquitectura fundamental y el paradigma de las Fly Machines

A diferencia de las plataformas tradicionales de funciones como servicio (FaaS) o las de plataforma como servicio (PaaS) que abstraen completamente el servidor, Fly.io opera bajo el concepto de **Fly Machines**. Estas son unidades de computación ligeras que arrancan en milisegundos, proporcionando el aislamiento de un hipervisor con la agilidad de un contenedor. Esta arquitectura permite a las aplicaciones mantener procesos de larga duración, ejecutar tareas programadas y gestionar estados persistentes sin los problemas de "arranque en frío" comunes en entornos sin servidor.

El orquestador de estas máquinas es **Fly Launch**, una herramienta diseñada para gestionar grupos de máquinas como una única aplicación lógica. Este sistema utiliza archivos de configuración específicos y una interfaz de línea de comandos robusta para automatizar el ciclo de vida de la infraestructura, desde la provisión inicial hasta el escalado horizontal y vertical basado en métricas de tráfico y rendimiento.

---

## 2. Gestión integral mediante la interfaz de línea de comandos (flyctl)

La filosofía de Fly.io es **"CLI-first"**, situando a la herramienta `flyctl` (también ejecutable como `fly`) en el centro de la experiencia del desarrollador. Esta decisión estratégica se fundamenta en la reproducibilidad, la facilidad de integración en flujos de CI/CD y la capacidad de realizar tareas complejas sin abandonar el terminal de desarrollo.

### Instalación y configuración inicial de flyctl
La herramienta `flyctl` es un binario independiente escrito en Go, lo que garantiza su compatibilidad multiplataforma. El proceso de instalación se adapta a los principales sistemas operativos:

| Sistema Operativo | Comando de Instalación / Método | Consideración Técnica |
| :--- | :--- | :--- |
| **macOS** | `brew install flyctl` o `curl -L https://fly.io/install.sh \| sh` | Se recomienda Homebrew para actualizaciones automáticas. |
| **Linux** | `curl -L https://fly.io/install.sh \| sh` | Requiere añadir el directorio al `PATH` en el archivo `.bashrc` o `.zshrc`. |
| **Windows** | `pwsh -Command "iwr https://fly.io/install.ps1 -useb \| iex"` | Requiere PowerShell; permite el uso del comando `fly` tras la instalación. |

Tras la instalación, el acceso a la plataforma se gestiona mediante `fly auth signup` para nuevos usuarios o `fly auth login` para cuentas existentes.

### Orquestación de aplicaciones y despliegue
El comando `fly launch` representa el punto de entrada para cualquier proyecto nuevo. Al ejecutarse en el directorio raíz de una aplicación, `fly launch`:
1.  Realiza una detección automática del framework (Node.js, Rails, Django, Elixir, etc.).
2.  Propone una configuración inicial basada en mejores prácticas.
3.  Genera dos artefactos críticos: un `Dockerfile` (definición de imagen) y un `fly.toml` (gobierno del despliegue).

El despliegue efectivo se realiza mediante `fly deploy`. Es posible supervisar este proceso en tiempo real mediante `fly status` y `fly logs`.

### Administración avanzada de recursos y redes
*   **Gestión de Secretos**: El comando `fly secrets set KEY=VALUE` permite inyectar variables de entorno cifradas.
*   **Escalado de Instancias**: A través de `fly scale vm` (recursos de CPU/RAM) y `fly scale count` (número de réplicas).
*   **Networking y Seguridad**: `fly certs` para certificados SSL/TLS y `fly ips` para gestionar direcciones IP públicas/privadas.
*   **Acceso Directo**: `fly ssh console` proporciona un terminal seguro dentro de la máquina virtual en ejecución.

---

## 3. El archivo fly.toml: Blueprint de la infraestructura

El archivo `fly.toml` actúa como la fuente de verdad para la configuración de la aplicación.

### Secciones críticas y su impacto operativo
*   **Configuración Global**: Define el `app` y la `primary_region`.
*   **Sección de Construcción (`[build]`)**: Especifica el uso de Dockerfiles personalizados o Buildpacks.
*   **Servicios y Redes (`[[services]]`)**: Define el `internal_port` y los puertos externos expuestos (80, 443).
*   **Comprobaciones de Salud (`[[services.http_checks]]`)**: Define los endpoints y la frecuencia de verificación.

| Parámetro en fly.toml | Función Técnica | Riesgo de Configuración |
| :--- | :--- | :--- |
| `internal_port` | Puerto de escucha del proceso interno. | Error **PC01** si no coincide con el código. |
| `kill_signal` | Señal enviada para apagar la máquina (ej. `SIGINT`). | Cierre abrupto si la app no maneja la señal. |
| `kill_timeout` | Tiempo de gracia antes de forzar el apagado. | Pérdida de procesos en curso si es muy corto. |
| `auto_stop_machines` | Apaga máquinas si no hay tráfico entrante. | Latencia inicial al volver a encender (cold start). |
| `min_machines_running` | Mantiene un número mínimo de máquinas activas. | Incremento de costos operativos. |

---

## 4. Limitaciones y disparidades entre el CLI y el panel web

### Deficiencias en CI/CD y gestión de entornos
Fly.io no ofrece entornos de vista previa automáticos nativos; el usuario debe orquestar esta lógica utilizando herramientas externas como **GitHub Actions**. Asimismo, no cuenta con un sistema nativo para la gestión de entornos separados (staging/prod) dentro de una misma aplicación.

### Experiencia de usuario y rendimiento del Dashboard
El panel web se orienta a visualización de métricas. Se han reportado latencias significativas y problemas de consistencia, por lo que se recomienda el **CLI para tareas críticas**.

### Gestión de equipos y roles
La granularidad es limitada:
*   **Admin**: Control total sobre facturación y usuarios.
*   **Member**: Tareas técnicas pero sin capacidad de gestión organizacional.

---

## 5. Errores críticos en el hosting de aplicaciones web

### El problema de la interfaz de escucha (Binding)
El error más común es el fallo de conexión al puerto interno (**PC01/PC02**). Ocurre si la app escucha en `127.0.0.1`.
**Solución**: Configurar la aplicación para que escuche en `0.0.0.0` (IPv4) o `::` (IPv6).

### Fallos en las comprobaciones de salud (Health Checks)
1.  **Periodo de Gracia Insuficiente**: Si la app tarda más en arrancar que el `grace_period`.
2.  **Agotamiento de Recursos (OOM)**: El kernel termina el proceso por falta de RAM.
3.  **Errores de Configuración de Host**: Frameworks (como Rails) pueden bloquear peticiones de IPs internas no autorizadas.

### Categorización de códigos de error del Fly Proxy

| Código | Tipo | Significado | Causa Probable |
| :--- | :--- | :--- | :--- |
| **PP01** | Interno | Error en el socket TCP. | Problema de la plataforma Fly.io. |
| **PU01** | Upstream | Fallo en el handshake HTTP/2. | La app no maneja `h2c` correctamente. |
| **PC01** | Conexión | Conexión rechazada en el puerto. | La app no escucha en `0.0.0.0`. |
| **PC05** | Tiempo | Tiempo de espera agotado. | App sobrecargada o bloqueada por E/S. |
| **PR01** | Selección | No hay máquinas saludables. | Fallo general de todas las instancias. |

---

## 6. Gestión y migración de bases de datos: El ecosistema Postgres

Fly.io proporciona una aplicación de Postgres "no gestionada" que corre sobre microVMs. El usuario tiene control total pero asume la responsabilidad del mantenimiento.

### Arquitectura de Postgres en Fly.io
Utiliza herramientas como `stolon` o `repmgr` para la elección de líder. El puerto **5432** conecta con el nodo primario, mientras que el **5433** conecta con réplicas de solo lectura.

### Procedimientos de migración de bases de datos
Se realiza comúnmente mediante `fly pg import`. Pasos recomendados:
1.  **Provisión**: `fly pg create` en la región destino.
2.  **Preparación**: Poner la app original en solo lectura.
3.  **Ejecución**: `fly pg import $SOURCE_URI --app $TARGET_APP`.
4.  **Vinculación**: `fly secrets set DATABASE_URL=...`.

### Errores comunes en la migración e importación
*   **OOM en la Máquina de Migración**: Por defecto usa 256MB de RAM; bases grandes pueden necesitar más.
*   **Estado de Solo Lectura Persistente**: Si se agota el disco, el clúster puede quedar bloqueado.
    ```sql
    -- Para restaurar la capacidad de escritura:
    ALTER DATABASE nombre_de_tu_db SET default_transaction_read_only = off;
    ```

### Consistencia eventual y el encabezado `fly-replay`
Si una app en una región remota necesita escribir en la DB, puede responder con el encabezado `fly-replay: region=iad`. El Fly Proxy reenviará automáticamente la petición a la región del líder.

---

## 7. Seguridad, Identidad y Gobernanza

### Roles y Tokens de Acceso
*   **Deploy Tokens**: Limitados a una única aplicación (ideal para CI/CD).
*   **Read-only Tokens**: Útiles para monitorización.
*   **SSH-only Tokens**: Solo para acceso vía terminal.

### Autenticación Única (SSO)
Soporta integración con **Google Workspace** y **GitHub Organizations**.

---

## 8. Consideraciones sobre Costos y Facturación

Modelo de facturación basado en el uso por segundo.

| Estado de la Máquina | Cargos Aplicables | Justificación Técnica |
| :--- | :--- | :--- |
| **Started** | CPU + RAM (Completo) | Consumo activo de recursos. |
| **Stopped** | Almacenamiento rootfs | $0.15/GB/mes por el espacio en host. |
| **Volumes** | $0.15 por GB provisionado | Se facturan siempre que existan. |

---

## 9. Síntesis y Recomendaciones Estratégicas

1.  **Priorizar el CLI**: Evitar el dashboard para operaciones críticas.
2.  **Configurar Redes con Rigor**: Siempre escuchar en `0.0.0.0` y ajustar `grace_period`.
3.  **Gestionar Postgres con Cautela**: Sobredimensionar RAM durante migraciones y usar clústeres HA en producción.
4.  **Seguridad por Capas**: Usar tokens específicos para automatización.

Fly.io continúa evolucionando con servicios como **Managed Postgres (MPG)** y **Tigris**, cerrando brechas en servicios gestionados.
