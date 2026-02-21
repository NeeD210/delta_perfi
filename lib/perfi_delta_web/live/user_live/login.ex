defmodule PerfiDeltaWeb.UserLive.Login do
  use PerfiDeltaWeb, :live_view

  alias PerfiDelta.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app view_module={__MODULE__} flash={@flash} current_scope={@current_scope}>
      <div class="min-h-[90vh] flex flex-col items-center justify-center p-4">
        <div class="w-full max-w-sm space-y-12">
          
          <!-- Splash View -->
          <div :if={@view == :splash} class="flex flex-col items-center justify-center space-y-12 animate-fade-in">
            <!-- Perfectly Centered Logo -->
            <div class="relative py-12">
              <.link href={~p"/"} class="block transition-transform hover:scale-105 active:scale-95">
                <img src={~p"/images/PerFi_logo.png"} class="h-24 w-auto block dark:hidden drop-shadow-2xl animate-scale-in" alt="PerFi Delta" />
                <img src={~p"/images/perfi_logo_dark.png"} class="h-24 w-auto hidden dark:block drop-shadow-2xl animate-scale-in" alt="PerFi Delta" />
              </.link>
              <div class="absolute -inset-8 bg-primary/10 blur-3xl rounded-full -z-10 animate-pulse"></div>
            </div>

            <!-- Action Buttons -->
            <div class="w-full space-y-4 pt-4 stagger-1">
              <button
                phx-click="show_login"
                class="btn btn-primary w-full shadow-lg shadow-primary/20 h-14 text-lg font-bold"
              >
                Iniciar sesión
              </button>
              
              <.link
                navigate={~p"/users/register"}
                class="btn btn-outline btn-glass w-full border-base-content/10 hover:bg-base-content/5 hover:border-base-content/20 h-14 text-lg"
              >
                Registrarme
              </.link>
            </div>
          </div>

          <!-- Login Form View -->
          <div :if={@view == :form} class="space-y-8">
            <!-- Logo Hero Section (Smaller/Shifted up) -->
            <div class="flex flex-col items-center space-y-4">
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
                <h2 class="text-xl font-bold">Iniciar sesión</h2>
                <p class="text-sm text-base-content/60">
                  <%= if @current_scope do %>
                    Necesitas reautenticarte para realizar acciones sensibles.
                  <% else %>
                    Ingresa tus credenciales para continuar
                  <% end %>
                </p>
              </div>

              <!-- Selection Toggle (Pill style) -->
              <div class="account-toggle account-toggle-2">
                <div class="account-toggle-pill" style={"transform: translateX(#{if @login_method == :magic, do: "0%", else: "100%"});"}></div>
                <button
                  type="button"
                  phx-click="select_method"
                  phx-value-method="magic"
                  class={["account-toggle-option", @login_method == :magic && "active"]}
                >
                  Enlace Mágico
                </button>
                <button
                  type="button"
                  phx-click="select_method"
                  phx-value-method="password"
                  class={["account-toggle-option", @login_method == :password && "active"]}
                >
                  Contraseña
                </button>
              </div>

              <!-- Single email input (shared) -->
              <.form for={%{}} as={:email_form} phx-change="update_email" phx-submit="update_email">
                <div class="space-y-1.5">
                  <label for="shared_email" class="text-sm font-semibold px-1 text-base-content/80">Email</label>
                  <input
                    type="email"
                    id="shared_email"
                    name="email"
                    value={@email}

                    class="input input-glass w-full focus:ring-2 focus:ring-primary/20"
                    placeholder="tu@email.com"
                    autocomplete="email"
                    required
                    phx-debounce="blur"
                  />
                </div>
              </.form>

              <!-- Magic Link Form -->
              <div :if={@login_method == :magic} class="space-y-5 animate-fade-in">
                <div class="text-sm text-base-content/70 bg-primary/5 border border-primary/10 p-3 rounded-xl flex gap-2 items-start">
                  <.icon name="hero-envelope" class="size-5 text-primary shrink-0" /> 
                  <p>Te enviaremos un enlace seguro de inicio de sesión a tu email para que no necesites contraseña.</p>
                </div>

                <.form
                  for={@form}
                  id="login_form_magic"
                  action={~p"/users/log-in"}
                  phx-submit="submit_magic"
                >
                  <input type="hidden" name="user[email]" value={@email} />
                  <.button class="btn btn-primary w-full shadow-lg shadow-primary/20 h-12">
                    Enviar Enlace <span aria-hidden="true" class="ml-1">→</span>
                  </.button>
                </.form>
              </div>

              <!-- Password Form -->
              <div :if={@login_method == :password} class="space-y-5 animate-fade-in">
                <.form
                  :let={f}
                  for={@form}
                  id="login_form_password"
                  action={~p"/users/log-in"}
                  phx-submit="submit_password"
                  phx-trigger-action={@trigger_submit}
                  class="space-y-4"
                >
                  <input type="hidden" name={f[:email].name} value={@email} />

                  <div class="space-y-1.5">
                    <label class="text-sm font-semibold px-1 text-base-content/80">Contraseña</label>
                    <input
                      type="password"
                      name={f[:password].name}
                      id={f[:password].id}
                      class="input input-glass w-full focus:ring-2 focus:ring-primary/20"
                      placeholder="••••••••"
                      required
                    />
                    <.error :for={msg <- f[:password].errors}><%= msg %></.error>
                  </div>

                  <div class="flex items-center justify-between">
                    <label class="label cursor-pointer justify-start gap-3 group px-1">
                      <input
                        type="checkbox"
                        name={f[:remember_me].name}
                        value="true"
                        class="checkbox checkbox-primary checkbox-sm rounded-md transition-all group-hover:scale-110"
                        checked
                      />
                      <span class="label-text text-sm font-medium transition-colors group-hover:text-primary">Mantenerme conectado</span>
                    </label>
                  </div>

                  <.button class="btn btn-primary w-full shadow-lg shadow-primary/20 h-12">
                    Iniciar sesión <span aria-hidden="true" class="ml-1">→</span>
                  </.button>
                </.form>
              </div>
            </div>

              <div class="flex flex-col items-center gap-4">
                <p class="text-xs font-semibold text-base-content/40">
                  ¿No tienes cuenta?
                  <.link navigate={~p"/users/register"} class="text-primary hover:underline underline-offset-4 ml-1">
                    Regístrate
                  </.link>
                </p>
              </div>

              <div class="pt-2">
                <.link navigate={~p"/users/resend-confirmation"} class="text-xs font-semibold text-base-content/40 hover:text-primary transition-colors underline decoration-base-content/20 underline-offset-4">
                  ¿No recibiste el email de confirmación?
                </.link>
              </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)]) ||
        ""

    form = to_form(%{"email" => email}, as: "user")

    view = 
      case params["view"] do
        "splash" -> :splash
        _ -> :form
      end

     {:ok,
      assign(socket,
        view: view,
        form: form,
        trigger_submit: false,
        login_method: :password,
        email: email,
        theme: "dark"
      )}
  end

  @impl true
  def handle_event("show_login", _, socket), do: {:noreply, assign(socket, :view, :form)}
  def handle_event("show_splash", _, socket), do: {:noreply, assign(socket, :view, :splash)}

  def handle_event("select_method", %{"method" => method}, socket) do
    login_method = String.to_existing_atom(method)
    {:noreply, assign(socket, :login_method, login_method)}
  end

  def handle_event("update_email", params, socket) do
    email =
      case params do
        %{"email_form" => %{"email" => email}} -> email
        %{"email" => email} -> email
        %{"value" => email} -> email
        _ -> socket.assigns.email
      end

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
