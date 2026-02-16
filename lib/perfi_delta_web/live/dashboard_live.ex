defmodule PerfiDeltaWeb.DashboardLive do
  use PerfiDeltaWeb, :live_view

  alias PerfiDelta.Finance
  alias PerfiDelta.Services.ExchangeRateService
  import PerfiDeltaWeb.Helpers.NumberHelpers, only: [format_currency: 2]

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    # Obtener datos del usuario
    latest_snapshot = Finance.get_latest_confirmed_snapshot(user_id)
    accounts = Finance.list_accounts_with_latest_balances(user_id)
    snapshot_count = Finance.count_confirmed_snapshots(user_id)
    avg_expenses = Finance.get_average_monthly_expenses(user_id)

    # Calcular Runway (Libertad Financiera)
    # Liquid NW / Gastos Promedio
    liquid_nw = sum_by_type(accounts, :liquid)

    runway =
      if Decimal.gt?(avg_expenses, 0) do
        Decimal.div(liquid_nw, avg_expenses) |> Decimal.round(1)
      else
        nil
      end

    # Obtener cotización del dólar para conversión
    dolar_rate = fetch_dolar_rate()

    socket =
      socket
      |> assign(:page_title, "Inicio")
      |> assign(:latest_snapshot, latest_snapshot)
      |> assign(:accounts, accounts)
      |> assign(:snapshot_count, snapshot_count)
      |> assign(:is_zero_state, snapshot_count == 1)
      |> assign(:runway, runway)
      |> assign(:dolar_rate, dolar_rate)
      |> assign(:display_currency, "USD")
      |> assign(:needs_onboarding, !socket.assigns.current_scope.user.onboarding_completed)

    # Redirigir si no completó el onboarding
    if !socket.assigns.current_scope.user.onboarding_completed do
      {:ok, push_navigate(socket, to: ~p"/onboarding")}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("change_currency", %{"currency" => currency}, socket) do
    {:noreply, assign(socket, :display_currency, currency)}
  end

  defp fetch_dolar_rate do
    case ExchangeRateService.fetch_dolar_blue() do
      {:ok, rate} -> rate
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-6">
      <!-- Hero Section -->
      <div class="flex items-center justify-between mb-8 animate-fade-in">
        <div>
          <p class="text-sm opacity-60 mb-1"><%= today_date() %></p>
          <h1 class="text-3xl font-extrabold text-gradient-hero"><%= today_greeting() %></h1>
        </div>
        <!-- Currency Toggle Pill -->
        <div class="currency-toggle">
          <div class="currency-toggle-pill" style={"transform: translateX(#{if @display_currency == "ARS", do: "100%", else: "0"});"}></div>
          <button
            phx-click="change_currency"
            phx-value-currency="USD"
            class={"currency-toggle-option #{if @display_currency == "USD", do: "active"}"}
          >
            USD
          </button>
          <button
            phx-click="change_currency"
            phx-value-currency="ARS"
            class={"currency-toggle-option #{if @display_currency == "ARS", do: "active"}"}
          >
            ARS
          </button>
        </div>
      </div>

      <%= if @needs_onboarding do %>
        <!-- Onboarding Card -->
        <div class="glass-card p-6 mb-6 animate-scale-in">
          <div class="text-center">
            <div class="w-20 h-20 mx-auto mb-4 rounded-2xl bg-gradient-to-br from-indigo-500/20 to-purple-500/20 flex items-center justify-center">
              <span class="hero-sparkles text-4xl text-indigo-600"></span>
            </div>
            <h2 class="text-2xl font-bold mb-2 text-gradient-hero">Bienvenido a PerFi Delta</h2>
            <p class="text-gray-600 mb-6">
              Vamos a configurar tu mapa financiero.
              Solo necesitas agregar tus cuentas y deudas actuales.
            </p>
            <.link navigate={~p"/onboarding"} class="fab-button w-full h-auto py-4 rounded-xl touch-target">
              <span class="hero-rocket-launch mr-2 text-xl"></span>
              <span class="font-semibold">Comenzar Setup</span>
            </.link>
          </div>
        </div>
      <% else %>
        <!-- Score Card - Patrimonio Neto -->
        <div class="score-card mb-6 animate-slide-up">
          <%= if @latest_snapshot do %>
            <div class="relative z-10">
              <p class="text-sm opacity-60 mb-2">Patrimonio Neto</p>
              <p class="net-worth-display mb-6">
                <%= format_display_currency(@latest_snapshot.total_net_worth_usd, @display_currency, @dolar_rate) %>
              </p>

              <!-- Progress-like indicator -->
              <div class="mb-6">
                <div class="flex justify-between text-xs opacity-60 mb-2">
                  <span>Balance General</span>
                  <span>100%</span>
                </div>
                <div class="progress-glass">
                  <div class="progress-glass-fill" style="width: 100%"></div>
                </div>
              </div>

              <%= if @is_zero_state do %>
                <!-- Zero State: Línea base establecida -->
                <div class="glass-card-static p-5 rounded-xl text-center">
                  <div class="w-12 h-12 mx-auto mb-3 rounded-full bg-gradient-to-br from-indigo-500/20 to-purple-500/20 flex items-center justify-center">
                    <span class="hero-sparkles text-2xl text-indigo-400"></span>
                  </div>
                  <p class="font-semibold text-base mb-1">Tu línea base está establecida</p>
                  <p class="text-sm opacity-60">
                    Cuando hagas tu próximo cierre, verás cuánto ahorraste
                    y cuánto rindieron tus inversiones.
                  </p>
                </div>
              <% else %>
                <!-- Normal State: Ahorro + Rendimiento -->
                <div class="grid grid-cols-2 gap-4">
                  <div class="glass-card-static p-4 rounded-xl">
                    <div class="flex items-center gap-2 mb-2">
                      <div class="icon-badge icon-badge-liquid">
                        <span class="hero-arrow-trending-up"></span>
                      </div>
                      <span class="text-xs opacity-60">Ahorro</span>
                    </div>
                    <p class="text-xl font-mono-numbers font-bold text-savings">
                      <%= format_signed_display_currency(@latest_snapshot.total_savings_usd, @display_currency, @dolar_rate) %>
                    </p>
                  </div>
                  <div class="glass-card-static p-4 rounded-xl">
                    <div class="flex items-center gap-2 mb-2">
                      <div class="icon-badge icon-badge-investment">
                        <span class="hero-chart-bar"></span>
                      </div>
                      <span class="text-xs opacity-60">Rendimiento</span>
                    </div>
                    <p class="text-xl font-mono-numbers font-bold text-yield">
                      <%= format_signed_display_currency(@latest_snapshot.total_yield_usd, @display_currency, @dolar_rate) %>
                    </p>
                  </div>
                </div>
              <% end %>

              <%= if @runway do %>
                <!-- Runway Card (Libertad Financiera) -->
                <div class="mt-6 pt-6 border-t border-base-content/10">
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-xs opacity-60 uppercase tracking-wider font-bold">Libertad Financiera</span>
                    <span class={"badge badge-sm font-bold #{runway_badge_class(@runway)}"}>
                      <%= runway_status_label(@runway) %>
                    </span>
                  </div>
                  <div class="flex items-end gap-2">
                    <p class={"text-3xl font-mono-numbers font-extrabold #{runway_text_class(@runway)}"}>
                      <%= Decimal.to_string(@runway) %>
                    </p>
                    <p class="text-sm opacity-60 mb-1">meses de vida</p>
                  </div>
                  <p class="text-[10px] opacity-40 mt-1">
                    Basado en tus gastos promedio de los últimos meses.
                  </p>
                </div>
              <% end %>

              <p class="text-xs opacity-40 mt-4 text-center">
                Último cierre: <%= format_month(@latest_snapshot.month) %> <%= @latest_snapshot.year %>
              </p>
            </div>
          <% else %>
            <p class="text-center opacity-60 py-8">
              Aún no tienes cierres de mes.
            </p>
          <% end %>
        </div>

        <!-- CTA Cierre de Mes -->
        <%= if should_show_closure_cta?(@latest_snapshot) do %>
          <.link navigate={~p"/cierre"} class="glass-card flex items-center justify-between p-4 mb-6 animate-fade-in stagger-1">
            <div class="flex items-center gap-3">
              <div class="icon-badge icon-badge-investment">
                <span class="hero-calendar-days"></span>
              </div>
              <div>
                <p class="font-semibold">Cierre de <%= current_month_name() %></p>
                <p class="text-xs opacity-60">Actualiza tu patrimonio</p>
              </div>
            </div>
            <span class="hero-chevron-right text-xl opacity-40"></span>
          </.link>
        <% end %>

        <!-- Quick Stats -->
        <div class="grid grid-cols-3 gap-3 mb-6">
          <div class="glass-card p-4 text-center animate-fade-in stagger-1">
            <div class="icon-badge icon-badge-liquid mx-auto mb-2">
              <span class="hero-banknotes"></span>
            </div>
            <p class="text-lg font-mono-numbers font-bold"><%= format_compact(sum_by_type(@accounts, :liquid), @display_currency, @dolar_rate) %></p>
            <p class="text-xs opacity-60">Líquidas</p>
          </div>
          <div class="glass-card p-4 text-center animate-fade-in stagger-2">
            <div class="icon-badge icon-badge-investment mx-auto mb-2">
              <span class="hero-chart-bar"></span>
            </div>
            <p class="text-lg font-mono-numbers font-bold"><%= format_compact(sum_by_type(@accounts, :investment), @display_currency, @dolar_rate) %></p>
            <p class="text-xs opacity-60">Inversiones</p>
          </div>
          <div class="glass-card p-4 text-center animate-fade-in stagger-3">
            <div class="icon-badge icon-badge-liability mx-auto mb-2">
              <span class="hero-credit-card"></span>
            </div>
            <p class="text-lg font-mono-numbers font-bold text-debt"><%= format_compact(sum_by_type(@accounts, :liability), @display_currency, @dolar_rate) %></p>
            <p class="text-xs opacity-60">Deudas</p>
          </div>
        </div>

        <!-- Lista de cuentas recientes -->
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-bold">Tus Cuentas</h2>
          <.link navigate={~p"/cuentas"} class="text-sm font-medium text-indigo-600">Ver todas</.link>
        </div>
        <div class="space-y-3">
          <%= for {account, idx} <- Enum.with_index(Enum.take(@accounts, 5)) do %>
            <div class={"list-item-glass animate-fade-in stagger-#{min(idx + 1, 5)}"}>
              <div class={"icon-badge icon-badge-#{account.type}"}>
                <span class={account_icon(account.type)}></span>
              </div>
              <div class="flex-1 min-w-0">
                <p class="font-medium truncate"><%= account.name %></p>
                <p class="text-xs opacity-50"><%= account.currency %></p>
              </div>
              <span class={"font-mono-numbers font-semibold #{account_amount_class(account.type)}"}>
                <%= format_account_balance(account, @display_currency, @dolar_rate) %>
              </span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Helpers

  defp today_greeting do
    hour = DateTime.now!("America/Argentina/Buenos_Aires").hour

    cond do
      hour < 12 -> "Buenos días"
      hour < 19 -> "Buenas tardes"
      true -> "Buenas noches"
    end
  end

  defp today_date do
    now = DateTime.now!("America/Argentina/Buenos_Aires")
    days = ~w(Domingo Lunes Martes Miércoles Jueves Viernes Sábado)
    months = ~w(Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre Octubre Noviembre Diciembre)
    day_name = Enum.at(days, Date.day_of_week(now) |> rem(7))
    month_name = Enum.at(months, now.month - 1)
    "#{day_name}, #{now.day} de #{month_name}"
  end

  defp format_display(nil), do: "-"
  defp format_display(decimal), do: format_currency(decimal, [])

  defp convert_usd_to_display(amount_usd, "USD", _dolar_rate), do: amount_usd
  defp convert_usd_to_display(amount_usd, "ARS", nil), do: amount_usd
  defp convert_usd_to_display(amount_usd, "ARS", dolar_rate) do
    Decimal.mult(amount_usd, dolar_rate)
  end

  defp currency_symbol("USD"), do: "US$"
  defp currency_symbol("ARS"), do: "$"
  defp currency_symbol(_), do: "$"

  defp format_display_currency(nil, _currency, _rate), do: "-"
  defp format_display_currency(amount_usd, display_currency, dolar_rate) do
    converted = convert_usd_to_display(amount_usd, display_currency, dolar_rate)
    "#{currency_symbol(display_currency)} #{format_display(converted)}"
  end

  defp format_signed_display_currency(nil, _currency, _rate), do: "-"
  defp format_signed_display_currency(amount_usd, display_currency, dolar_rate) do
    converted = convert_usd_to_display(amount_usd, display_currency, dolar_rate)
    prefix = if Decimal.positive?(converted), do: "+", else: ""
    "#{prefix}#{currency_symbol(display_currency)} #{format_display(Decimal.abs(converted))}"
  end

  # format_currency and add_thousands_separator delegated to NumberHelpers via import

  defp format_month(month) do
    months = ~w(Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre Octubre Noviembre Diciembre)
    Enum.at(months, month - 1)
  end

  defp current_month_name do
    DateTime.now!("America/Argentina/Buenos_Aires").month
    |> format_month()
  end

  defp should_show_closure_cta?(nil), do: true
  defp should_show_closure_cta?(snapshot) do
    now = DateTime.now!("America/Argentina/Buenos_Aires")
    snapshot.month != now.month or snapshot.year != now.year
  end

  defp sum_by_type(accounts, type) do
    accounts
    |> Enum.filter(&(&1.type == type))
    |> Enum.reduce(Decimal.new(0), fn account, acc ->
      case account.latest_balance do
        nil ->
          acc

        balance ->
          case balance.amount_usd do
            nil -> acc
            amount_usd -> Decimal.add(acc, amount_usd)
          end
      end
    end)
  end

  defp format_compact(decimal_usd, display_currency, dolar_rate) do
    converted = convert_usd_to_display(decimal_usd, display_currency, dolar_rate)
    abs_value = Decimal.abs(converted)
    is_negative = Decimal.negative?(converted)
    prefix = if is_negative, do: "-", else: ""

    formatted =
      cond do
        Decimal.compare(abs_value, Decimal.new(1_000_000)) != :lt ->
          abs_value
          |> Decimal.div(Decimal.new(1_000_000))
          |> Decimal.round(1)
          |> Decimal.to_string()
          |> Kernel.<>("M")

        Decimal.compare(abs_value, Decimal.new(1_000)) != :lt ->
          abs_value
          |> Decimal.div(Decimal.new(1_000))
          |> Decimal.round(1)
          |> Decimal.to_string()
          |> Kernel.<>("K")

        true ->
          abs_value
          |> Decimal.round(0)
          |> Decimal.to_string()
      end

    "#{prefix}#{currency_symbol(display_currency)} #{formatted}"
  end

  defp format_account_balance(account, display_currency, dolar_rate) do
    case account.latest_balance do
      nil ->
        "-"

      balance ->
        # Si amount_usd es nil, mostrar que no hay datos
        case balance.amount_usd do
          nil ->
            "-"

          amount_usd ->
            converted = convert_usd_to_display(amount_usd, display_currency, dolar_rate)
            formatted = format_display(Decimal.abs(converted))
            prefix = if Decimal.negative?(converted), do: "-", else: ""
            "#{prefix}#{currency_symbol(display_currency)} #{formatted}"
        end
    end
  end

  defp account_icon(:liquid), do: "hero-banknotes"
  defp account_icon(:investment), do: "hero-chart-bar"
  defp account_icon(:liability), do: "hero-credit-card"

  defp account_amount_class(:liquid), do: "text-savings"
  defp account_amount_class(:investment), do: "text-yield"
  defp account_amount_class(:liability), do: "text-debt"

  defp runway_badge_class(months) do
    cond do
      Decimal.lt?(months, 3) -> "badge-error"
      Decimal.lt?(months, 6) -> "badge-warning"
      true -> "badge-success"
    end
  end

  defp runway_text_class(months) do
    cond do
      Decimal.lt?(months, 3) -> "text-error"
      Decimal.lt?(months, 6) -> "text-warning"
      true -> "text-success"
    end
  end

  defp runway_status_label(months) do
    cond do
      Decimal.lt?(months, 3) -> "Crítico"
      Decimal.lt?(months, 6) -> "Precario"
      true -> "Saludable"
    end
  end
end
