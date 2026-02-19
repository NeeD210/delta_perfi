defmodule PerfiDeltaWeb.UserLive.ResendConfirmation do
  use PerfiDeltaWeb, :live_view

  alias PerfiDelta.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app view_module={__MODULE__} flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center mb-6">
          <.header>
            Reenviar email de confirmación
            <:subtitle>
              ¿No recibiste el email de confirmación? Ingresa tu email y te enviaremos uno nuevo.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="resend_confirmation_form" phx-submit="resend">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            placeholder="tu@email.com"
            autocomplete="email"
            required
            phx-mounted={JS.focus()}
          />

          <div class="mt-4">
            <.button phx-disable-with="Enviando..." class="btn btn-primary w-full">
              Reenviar email de confirmación
            </.button>
          </div>
        </.form>

        <div class="mt-6 text-center text-sm">
          <.link navigate={~p"/users/log-in"} class="text-brand hover:underline">
            ← Volver al inicio de sesión
          </.link>
        </div>

        <div class="mt-6 alert alert-info">
          <.icon name="hero-information-circle" class="size-5" />
          <div class="text-sm">
            <p class="font-semibold">Consejos:</p>
            <ul class="list-disc list-inside mt-2 space-y-1">
              <li>Revisa tu carpeta de spam</li>
              <li>Verifica que escribiste bien tu email</li>
              <li>Los enlaces expiran después de 7 días</li>
            </ul>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    form = to_form(%{"email" => ""}, as: "user")
    {:ok, assign(socket, form: form)}
  end

  @impl true
  def handle_event("resend", %{"user" => %{"email" => email}}, socket) do
    case Accounts.resend_confirmation_instructions(email) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Si tu email está registrado y no confirmado, recibirás un nuevo enlace de confirmación."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, :already_confirmed} ->
        {:noreply,
         socket
         |> put_flash(:info, "Esta cuenta ya está confirmada. Puedes iniciar sesión.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, :not_found} ->
        # Don't reveal if email exists (security)
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Si tu email está registrado y no confirmado, recibirás un nuevo enlace de confirmación."
         )
         |> push_navigate(to: ~p"/users/log-in")}
    end
  end
end
