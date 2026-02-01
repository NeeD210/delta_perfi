defmodule PerfiDeltaWeb.UserLive.Login do
  use PerfiDeltaWeb, :live_view

  alias PerfiDelta.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-6">
        <div class="text-center">
          <.header>
            <p>Iniciar sesión</p>
            <:subtitle>
              <%= if @current_scope do %>
                Necesitas reautenticarte para realizar acciones sensibles.
              <% else %>
                ¿No tienes una cuenta? <.link
                  navigate={~p"/users/register"}
                  class="font-semibold text-brand hover:underline"
                  phx-no-format
                >Regístrate</.link>
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <!-- Tab selection -->
        <div role="tablist" class="tabs tabs-boxed bg-base-200">
          <button
            type="button"
            role="tab"
            class={["tab", @login_method == :magic && "tab-active"]}
            phx-click="select_method"
            phx-value-method="magic"
          >
            Enlace Mágico
          </button>
          <button
            type="button"
            role="tab"
            class={["tab", @login_method == :password && "tab-active"]}
            phx-click="select_method"
            phx-value-method="password"
          >
            Contraseña
          </button>
        </div>

        <!-- Single email input (shared) -->
        <div>
          <label for="shared_email" class="label">
            <span class="label-text">Email</span>
          </label>
          <input
            type="email"
            id="shared_email"
            name="shared_email"
            value={@email}
            readonly={!!@current_scope}
            class="input input-bordered w-full"
            autocomplete="email"
            required
            phx-mounted={JS.focus()}
            phx-blur="update_email"
          />
        </div>

        <!-- Magic Link Form -->
        <div :if={@login_method == :magic} class="space-y-4">
          <div class="text-sm text-base-content/70 bg-base-200 p-3 rounded-lg">
            <.icon name="hero-envelope" class="size-4 inline" /> Te enviaremos un enlace seguro de inicio de sesión a tu email.
          </div>

          <.form
            for={@form}
            id="login_form_magic"
            action={~p"/users/log-in"}
            phx-submit="submit_magic"
          >
            <input type="hidden" name="user[email]" value={@email} />
            <.button class="btn btn-primary w-full">
              Enviar Enlace <span aria-hidden="true">→</span>
            </.button>
          </.form>
        </div>

        <!-- Password Form -->
        <div :if={@login_method == :password} class="space-y-4">
          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
          >
            <input type="hidden" name={f[:email].name} value={@email} />

            <.input
              field={f[:password]}
              type="password"
              label="Contraseña"
              autocomplete="current-password"
              required
            />

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-2">
                <input
                  type="checkbox"
                  name={f[:remember_me].name}
                  value="true"
                  class="checkbox checkbox-sm"
                  checked
                />
                <span class="label-text">Mantenerme conectado</span>
              </label>
            </div>

            <.button class="btn btn-primary w-full">
              Iniciar sesión <span aria-hidden="true">→</span>
            </.button>
          </.form>
        </div>

        <div class="mt-4 text-center text-sm text-base-content/70">
          <.link navigate={~p"/users/resend-confirmation"} class="hover:underline">
            ¿No recibiste el email de confirmación?
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)]) ||
        ""

    form = to_form(%{"email" => email}, as: "user")

    {:ok,
     assign(socket,
       form: form,
       trigger_submit: false,
       login_method: :password,
       email: email
     )}
  end

  @impl true
  def handle_event("select_method", %{"method" => method}, socket) do
    login_method = String.to_existing_atom(method)
    {:noreply, assign(socket, :login_method, login_method)}
  end

  def handle_event("update_email", %{"value" => email}, socket) do
    {:noreply, assign(socket, :email, email)}
  end

  def handle_event("submit_password", %{"user" => %{"password" => password}}, socket) do
    # Update form with current email before submitting
    form = to_form(%{"email" => socket.assigns.email, "password" => password}, as: "user")

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:trigger_submit, true)}
  end

  def handle_event("submit_magic", _params, socket) do
    email = socket.assigns.email

    if email != "" do
      case Accounts.get_user_by_email(email) do
        nil -> :noop
        user ->
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )
      end
    end

    info =
      "Si tu email está en nuestro sistema, recibirás instrucciones para iniciar sesión en breve."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end
end
