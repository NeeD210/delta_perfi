defmodule PerfiDeltaWeb.UserLive.Registration do
  use PerfiDeltaWeb, :live_view

  alias PerfiDelta.Accounts
  alias PerfiDelta.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app view_module={__MODULE__} flash={@flash} current_scope={@current_scope}>
      <div class="min-h-[90vh] flex flex-col items-center justify-center p-4">
        <div class="w-full max-w-sm space-y-12">
          <!-- Logo Hero Section -->
          <div class="flex flex-col items-center animate-scale-in">
            <div class="relative">
              <.link href={~p"/"} class="block transition-transform hover:scale-105 active:scale-95">
                <img src={~p"/images/PerFi_logo.png"} class="h-16 w-auto block dark:hidden drop-shadow-lg" alt="PerFi Delta" />
                <img src={~p"/images/perfi_logo_dark.png"} class="h-16 w-auto hidden dark:block drop-shadow-lg" alt="PerFi Delta" />
              </.link>
              <div class="absolute -inset-4 bg-primary/5 blur-2xl rounded-full -z-10 animate-pulse"></div>
            </div>
          </div>

          <div class="glass-card p-6 space-y-6 animate-fade-in stagger-1">
            <div class="text-center space-y-1">
              <h2 class="text-xl font-bold">Registrarse</h2>
              <p class="text-sm text-base-content/60">
                Crea tu cuenta en segundos
              </p>
            </div>

            <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate" class="space-y-5">
              <div class="space-y-1.5">
                <label class="text-sm font-semibold px-1 text-base-content/80">Email</label>
                <input
                  type="email"
                  name={@form[:email].name}
                  id={@form[:email].id}
                  value={@form[:email].value}
                  class="input input-glass w-full focus:ring-2 focus:ring-primary/20"
                  placeholder="tu@email.com"
                  autocomplete="username"
                  required
                  phx-mounted={JS.focus()}
                />
                <.error :for={msg <- @form[:email].errors}><%= msg %></.error>
              </div>

              <.button phx-disable-with="Creando cuenta..." class="btn btn-primary w-full shadow-lg shadow-primary/20 h-12">
                Crear cuenta <span aria-hidden="true" class="ml-1">→</span>
              </.button>
            </.form>

            <div :if={@show_resend_link} class="mt-4 p-3 bg-warning/10 border border-warning/20 rounded-xl flex gap-3 items-start animate-fade-in">
              <.icon name="hero-exclamation-triangle" class="size-5 text-warning shrink-0" />
              <div class="text-xs font-medium leading-relaxed">
                Este email ya está registrado pero no confirmado.
                <.link navigate={~p"/users/resend-confirmation"} class="block mt-1 font-bold underline decoration-warning/30 underline-offset-2 hover:text-warning">
                  ¿Reenviar email de confirmación?
                </.link>
              </div>
            </div>
          </div>

          <div class="text-center animate-fade-in stagger-2 pt-2">
            <p class="text-sm text-base-content/50">
              ¿Ya estás registrado? 
              <.link navigate={~p"/users/log-in"} class="font-bold text-primary hover:underline underline-offset-4 ml-1">
                Inicia sesión
              </.link>
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: PerfiDeltaWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    socket =
      socket
      |> assign_form(changeset)
      |> assign(show_resend_link: false)

    {:ok, socket}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    try do
      case Accounts.register_user(user_params) do
        {:ok, user} ->
          {:ok, _} =
            Accounts.deliver_login_instructions(
              user,
              &url(~p"/users/log-in/#{&1}")
            )

          {:noreply,
           socket
           |> put_flash(
             :info,
             "Se envió un email a #{user.email}, accede para confirmar tu cuenta."
           )
           |> push_navigate(to: ~p"/users/log-in")}

        {:error, %Ecto.Changeset{} = changeset} ->
          # Check if error is duplicate email
          show_resend =
            Enum.any?(changeset.errors, fn {field, {msg, _}} ->
              field == :email and String.contains?(msg, "ya")
            end)

          {:noreply,
           socket
           |> assign_form(changeset)
           |> assign(show_resend_link: show_resend)}
      end
    rescue
      e ->
        require Logger
        Logger.error("Error crítico en registro de usuario: #{inspect(e)}")
        Logger.error("Backtrace: #{inspect(__STACKTRACE__)}")

        {:noreply,
         socket
         |> put_flash(:error, "Ocurrió un error inesperado al crear la cuenta. Intente nuevamente.")
         |> assign(show_resend_link: false)
         |> assign_form(Accounts.change_user_email(%User{}, user_params, validate_unique: false))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
