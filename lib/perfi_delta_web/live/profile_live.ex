defmodule PerfiDeltaWeb.ProfileLive do
  use PerfiDeltaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Perfil")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-6">
      <!-- Header -->
      <div class="mb-8 animate-fade-in">
        <h1 class="text-3xl font-extrabold text-gradient-hero">Perfil</h1>
        <p class="text-sm opacity-60 mt-1"><%= @current_scope.user.email %></p>
      </div>

      <!-- User Card -->
      <div class="glass-card p-6 mb-6 animate-slide-up">
        <div class="flex items-center gap-4 mb-6">
          <div class="w-16 h-16 rounded-2xl bg-gradient-to-br from-indigo-500/20 to-purple-500/20 flex items-center justify-center">
            <span class="hero-user-circle text-3xl text-indigo-600"></span>
          </div>
          <div>
            <p class="font-bold text-lg"><%= @current_scope.user.email %></p>
            <p class="text-sm opacity-50">Usuario activo</p>
          </div>
        </div>
      </div>

      <!-- Settings List -->
      <div class="space-y-3">
        <!-- Theme Toggle -->
        <div 
          class="list-item-glass animate-fade-in stagger-1 cursor-pointer group"
          phx-click={Phoenix.LiveView.JS.dispatch("phx:toggle-theme")}
        >
          <div class="icon-badge icon-badge-investment transition-transform group-hover:scale-110">
            <span class="hero-sun dark:hidden"></span>
            <span class="hero-moon hidden dark:block"></span>
          </div>
          <div class="flex-1">
            <p class="font-medium">Tema</p>
            <p class="text-xs opacity-50">Cambiar apariencia</p>
          </div>
          <span class="hero-chevron-right opacity-40"></span>
        </div>

        <!-- Settings Link -->
        <.link navigate={~p"/users/settings"} class="list-item-glass animate-fade-in stagger-2">
          <div class="icon-badge icon-badge-liquid">
            <span class="hero-cog-6-tooth"></span>
          </div>
          <div class="flex-1">
            <p class="font-medium">Configuración</p>
            <p class="text-xs opacity-50">Cambiar contraseña y más</p>
          </div>
          <span class="hero-chevron-right opacity-40"></span>
        </.link>

        <!-- Logout -->
        <.link href={~p"/users/log-out"} method="delete" class="list-item-glass animate-fade-in stagger-3">
          <div class="icon-badge icon-badge-liability">
            <span class="hero-arrow-right-on-rectangle"></span>
          </div>
          <div class="flex-1">
            <p class="font-medium text-debt">Cerrar sesión</p>
            <p class="text-xs opacity-50">Salir de la cuenta</p>
          </div>
        </.link>
      </div>

      <!-- App Info -->
      <div class="mt-8 text-center opacity-40">
        <p class="text-xs">PerFi Delta v1.0</p>
        <p class="text-xs">Finanzas Zen 🧘</p>
      </div>
    </div>
    """
  end
end
