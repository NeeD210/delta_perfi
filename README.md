# PerFi Delta: Finanzas Zen

![PerFi Delta Logo](/delta_perfi_logo.png)

> **Tus finanzas, sin la culpa. Deja de anotar gastos. Empieza a medir riqueza.**

**PerFi Delta** es una herramienta de gestión financiera personal basada en la honestidad intelectual. A diferencia de los rastreadores de gastos tradicionales que te agobian con cada café, PerFi se enfoca en lo que realmente importa: tu **Patrimonio Neto (Net Worth)** y cómo este evoluciona mes a mes.

## 🧘‍♀️ La Filosofía Zen
La mayoría de las apps fallan porque el registro manual de gastos es insoportable. PerFi propone un enfoque reactivo pero potente:
1. **No anotes gastos**: Registrá solo tus saldos al final del mes.
2. **Medí el Delta**: La diferencia entre tu patrimonio de hoy y el del mes pasado es tu progreso real.
3. **Yield vs Savings**: Entendé cuánto de tu crecimiento es porque ahorraste (esfuerzo) y cuánto es porque tu dinero trabajó para vos (inversión).

## ✨ Funcionalidades Key
- 🚀 **Onboarding Guiado**: Un setup inicial que te ayuda a mapear Bancos, Dólares, Crypto y Deudas en minutos.
- 🧘‍♂️ **Ritual de Cierre**: Un proceso paso a paso para cerrar el mes financieramente, obteniendo tu "Score del Mes".
- 💳 **Gestión de Pasivos**: Tratamiento inteligente de tarjetas de crédito, separando el vencimiento actual de las cuotas futuras.
- 📈 **Bimonetariedad Nativa**: Pensado para el contexto argentino. Todo se normaliza a USD usando Dólar Blue/MEP en tiempo real, pero manteniendo tu registro original.
- 📉 **Analytics**: Gráficos de evolución para trackear tu camino hacia la libertad financiera.

## 🛠 Stack Tecnológico
- **Core**: [Elixir](https://elixir-lang.org/) + [Phoenix Framework](https://www.phoenixframework.org/)
- **Frontend**: Phoenix LiveView (Mobile-First, sin JS pesado)
- **Base de Datos**: PostgreSQL
- **Estilos**: Tailwind CSS 4 + DaisyUI 5 (Aconcagua/Zen aesthetic)

## 🚀 Setup Local

### Opción A: Docker (Recomendado)

Si tienes Docker instalado, puedes levantar todo el stack (App + Postgres) con un solo comando:

1. Asegúrate de que Docker Desktop esté corriendo.
2. Inicia los contenedores:
   ```bash
   docker-compose up --build -d
   ```
3. Ejecuta las migraciones:
   ```bash
   docker-compose run app mix ecto.migrate
   ```
4. Entra a [`localhost:4000`](http://localhost:4000).

### Opción B: Ejecución Nativa

#### Requisitos
- Elixir 1.16+ y Erlang/OTP 26+
- Node.js (opcional, para assets avanzados)
- PostgreSQL (puedes usar Docker solo para la base de datos)

#### Instalación
1. Cloná el repositorio.
2. Asegurate de tener la DB arriba:
   ```bash
   docker start perfi-postgres # o tu instancia local
   ```
3. Instalá dependencias y prepará la base de datos:
   ```bash
   cd perfi_delta
   mix setup
   ```
4. Iniciá el servidor:
   ```bash
   mix phx.server
   ```
5. Entra a [`localhost:4000`](http://localhost:4000).

## 🗺 Roadmap
- [x] MVP: Cierre de mes manual y dashboard básico.
- [ ] V2: Soporte para múltiples perfiles de riesgo.
- [ ] V2: Exportación a Sheets/PDF.
- [ ] V2: Integración con APIs bancarias (Automated sync).

---

Desarrollado con ❤️ para los que quieren paz mental financiera.
