defmodule PerfiDeltaWeb.HistoryLive do
  use PerfiDeltaWeb, :live_view

  alias PerfiDelta.Finance

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    snapshots = Finance.list_confirmed_snapshots(user_id)

    socket =
      socket
      |> assign(:page_title, "Historial")
      |> assign(:snapshots, snapshots)
      |> assign(:selected_snapshot, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("select", %{"id" => id}, socket) do
    snapshot = Finance.get_snapshot_with_details!(id)
    {:noreply, assign(socket, :selected_snapshot, snapshot)}
  end

  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, :selected_snapshot, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-6 animate-fade-in">
      <h1 class="text-2xl font-bold mb-6">Historial</h1>

      <%= if Enum.empty?(@snapshots) do %>
        <div class="text-center py-12 text-base-content/60">
          <span class="hero-chart-bar text-5xl mb-4 block opacity-30"></span>
          <p>Aún no tenés cierres de mes.</p>
          <p class="text-sm">Hacé tu primer cierre para ver tu historial.</p>
          <.link navigate={~p"/cierre"} class="btn btn-primary btn-sm mt-4">
            Hacer Cierre
          </.link>
        </div>
      <% else %>
        <!-- Gráfico simple de evolución -->
        <div class="card-zen p-4 mb-6">
          <p class="text-sm text-base-content/60 mb-3">Evolución del Patrimonio</p>
          <div class="h-32 flex items-end gap-1">
            <%= for snapshot <- Enum.reverse(@snapshots) |> Enum.take(12) do %>
              <div
                class="flex-1 bg-primary/20 hover:bg-primary/40 rounded-t transition-colors cursor-pointer"
                style={"height: #{bar_height(snapshot.total_net_worth_usd, @snapshots)}%"}
                phx-click="select"
                phx-value-id={snapshot.id}
                title={"#{format_month(snapshot.month)} #{snapshot.year}: US$ #{format_decimal(snapshot.total_net_worth_usd)}"}
              >
              </div>
            <% end %>
          </div>
          <div class="flex justify-between text-xs text-base-content/40 mt-2">
            <span><%= oldest_label(@snapshots) %></span>
            <span><%= newest_label(@snapshots) %></span>
          </div>
        </div>

        <!-- Lista de snapshots -->
        <div class="space-y-3">
          <%= for snapshot <- @snapshots do %>
            <div
              phx-click="select"
              phx-value-id={snapshot.id}
              class="card-zen p-4 cursor-pointer hover:border-primary/50 transition-colors"
            >
              <div class="flex items-center justify-between">
                <div>
                  <p class="font-semibold">
                    <%= format_month(snapshot.month) %> <%= snapshot.year %>
                  </p>
                  <p class="text-xs text-base-content/50">
                    Cerrado el <%= format_date(snapshot.updated_at) %>
                  </p>
                </div>
                <div class="text-right">
                  <p class="font-mono-numbers font-bold">
                    US$ <%= format_decimal(snapshot.total_net_worth_usd) %>
                  </p>
                  <div class="flex gap-2 text-xs">
                    <span class="text-savings">
                      <%= format_signed(snapshot.total_savings_usd) %>
                    </span>
                    <span class="text-yield">
                      <%= format_signed(snapshot.total_yield_usd) %>
                    </span>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Modal de detalle -->
      <%= if @selected_snapshot do %>
        <div class="fixed inset-0 bg-black/50 z-[60] flex items-end sm:items-center justify-center p-4">
          <div class="card-zen w-full max-w-md max-h-[80vh] overflow-y-auto p-6 animate-fade-in">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-bold">
                <%= format_month(@selected_snapshot.month) %> <%= @selected_snapshot.year %>
              </h2>
              <button phx-click="close_detail" class="btn btn-ghost btn-circle btn-sm">
                <span class="hero-x-mark"></span>
              </button>
            </div>

            <!-- Resumen -->
            <div class="score-card mb-4">
              <p class="text-sm text-base-content/60 text-center mb-1">Patrimonio Neto</p>
              <p class="text-3xl font-mono-numbers font-bold text-center mb-4">
                US$ <%= format_decimal(@selected_snapshot.total_net_worth_usd) %>
              </p>

              <div class="grid grid-cols-2 gap-3">
                <div class="bg-savings rounded-lg p-3 text-center">
                  <p class="text-xs text-base-content/60">Ahorro</p>
                  <p class="font-mono-numbers font-bold text-savings">
                    <%= format_signed(@selected_snapshot.total_savings_usd) %>
                  </p>
                </div>
                <div class="bg-yield rounded-lg p-3 text-center">
                  <p class="text-xs text-base-content/60">Rendimiento</p>
                  <p class="font-mono-numbers font-bold text-yield">
                    <%= format_signed(@selected_snapshot.total_yield_usd) %>
                  </p>
                </div>
              </div>
            </div>

            <!-- Cotizaciones guardadas -->
            <div class="text-sm text-base-content/60 mb-4">
              <p>Dólar Blue: $<%= format_rate(@selected_snapshot.exchange_rate_blue) %></p>
            </div>

            <!-- Detalle de cuentas -->
            <%= if length(@selected_snapshot.account_balances) > 0 do %>
              <h3 class="font-semibold text-sm mb-2">Detalle de Cuentas</h3>
              <div class="space-y-2 mb-4">
                <%= for balance <- @selected_snapshot.account_balances do %>
                  <div class="flex justify-between text-sm py-2 border-b border-base-300">
                    <span><%= balance.account.name %></span>
                    <span class={"font-mono-numbers #{if Decimal.negative?(balance.amount_usd), do: "text-error"}"}>
                      US$ <%= format_decimal(balance.amount_usd) %>
                    </span>
                  </div>
                <% end %>
              </div>
            <% end %>

            <!-- Flujos de inversión -->
            <%= if length(@selected_snapshot.investment_flows) > 0 do %>
              <h3 class="font-semibold text-sm mb-2">Flujos de Inversión</h3>
              <div class="space-y-2">
                <%= for flow <- @selected_snapshot.investment_flows do %>
                  <div class="flex justify-between text-sm py-2 border-b border-base-300">
                    <span><%= if flow.direction == :deposit, do: "Depósito", else: "Retiro" %></span>
                    <span class="font-mono-numbers">
                      US$ <%= format_decimal(flow.amount_usd) %>
                    </span>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helpers

  defp bar_height(value, snapshots) do
    max_value =
      snapshots
      |> Enum.map(& &1.total_net_worth_usd)
      |> Enum.filter(&(&1 != nil))
      |> Enum.max(fn -> Decimal.new(1) end)

    if Decimal.positive?(max_value) do
      Decimal.div(value || Decimal.new(0), max_value)
      |> Decimal.mult(100)
      |> Decimal.to_float()
      |> max(5)
    else
      5
    end
  end

  defp oldest_label([]), do: ""
  defp oldest_label(snapshots) do
    oldest = List.last(snapshots)
    "#{short_month(oldest.month)}/#{rem(oldest.year, 100)}"
  end

  defp newest_label([]), do: ""
  defp newest_label([newest | _]) do
    "#{short_month(newest.month)}/#{rem(newest.year, 100)}"
  end

  defp short_month(month) do
    ~w(Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic)
    |> Enum.at(month - 1)
  end

  defp format_month(month) do
    ~w(Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre Octubre Noviembre Diciembre)
    |> Enum.at(month - 1)
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y")
  end

  defp format_decimal(nil), do: "0"
  defp format_decimal(decimal) do
    decimal
    |> Decimal.round(0)
    |> Decimal.to_string()
    |> add_thousands_separator()
  end

  defp format_signed(nil), do: "$0"
  defp format_signed(decimal) do
    prefix = if Decimal.positive?(decimal), do: "+", else: ""
    "#{prefix}$#{format_decimal(Decimal.abs(decimal))}"
  end

  defp format_rate(nil), do: "-"
  defp format_rate(rate), do: Decimal.round(rate, 0) |> Decimal.to_string()

  defp add_thousands_separator(str) do
    str
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(".")
    |> String.reverse()
  end
end
