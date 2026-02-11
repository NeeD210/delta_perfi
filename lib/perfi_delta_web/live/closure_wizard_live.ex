defmodule PerfiDeltaWeb.ClosureWizardLive do
  @moduledoc """
  El "Ritual de Cierre" - Wizard paso a paso para el cierre mensual.
  """
  use PerfiDeltaWeb, :live_view

  alias PerfiDelta.Finance
  alias PerfiDelta.Services.ExchangeRateService
  import PerfiDeltaWeb.Helpers.NumberHelpers, only: [parse_currency: 1, format_currency: 2, format_signed: 1, format_rate: 1, format_smart_currency: 1]

  @steps [:rates, :assets, :liabilities, :flows, :income, :result]

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    # Obtener o crear snapshot draft para el mes actual
    {:ok, snapshot} = Finance.get_or_create_current_snapshot(user_id)
    accounts = Finance.list_accounts(user_id)

    # Pre-cargar saldos del mes anterior
    previous_balances = Finance.get_previous_balances_for_wizard(user_id)
    previous_snapshot = Finance.get_latest_confirmed_snapshot(user_id)

    socket =
      socket
      |> assign(:page_title, "Cierre de Mes")
      |> assign(:snapshot, snapshot)
      |> assign(:accounts, accounts)
      |> assign(:steps, @steps)
      |> assign(:current_step, :rates)
      |> assign(:step_index, 0)
      |> assign(:loading_rates, true)
      |> assign(:dolar_blue, nil)
      |> assign(:dolar_mep, nil)
      |> assign(:balances, previous_balances)
      |> assign(:previous_balances, previous_balances)
      |> assign(:previous_snapshot, previous_snapshot)
      |> assign(:liability_details, %{})
      |> assign(:flows, [])
      |> assign(:has_new_flows, false)
      |> assign(:flow_amount, "")
      |> assign(:flow_direction, :deposit)
      |> assign(:income_ars, "")
      |> assign(:income_usd, "")
      |> assign(:income, "")
      |> assign(:assets_filter, :liquid)
      |> assign(:result, nil)

    # Fetch rates async
    send(self(), :fetch_rates)

    {:ok, socket}
  end

  @impl true
  def handle_info(:fetch_rates, socket) do
    blue =
      case ExchangeRateService.fetch_dolar_blue() do
        {:ok, rate} -> rate
        _ -> nil
      end

    mep =
      case ExchangeRateService.fetch_dolar_mep() do
        {:ok, rate} -> rate
        _ -> nil
      end

    {:noreply,
     socket
     |> assign(:loading_rates, false)
     |> assign(:dolar_blue, blue)
     |> assign(:dolar_mep, mep)}
  end

  @impl true
  def handle_event("next_step", _, socket) do
    current_index = socket.assigns.step_index
    next_index = min(current_index + 1, length(@steps) - 1)
    next_step = Enum.at(@steps, next_index)

    socket =
      socket
      |> assign(:step_index, next_index)
      |> assign(:current_step, next_step)
      |> maybe_calculate_result()

    {:noreply, socket}
  end

  def handle_event("prev_step", _, socket) do
    current_index = socket.assigns.step_index
    prev_index = max(current_index - 1, 0)
    prev_step = Enum.at(@steps, prev_index)

    {:noreply,
     socket
     |> assign(:step_index, prev_index)
     |> assign(:current_step, prev_step)}
  end

  def handle_event("change_assets_filter", %{"type" => type}, socket) do
    filter_type = String.to_existing_atom(type)
    {:noreply, assign(socket, :assets_filter, filter_type)}
  end

  def handle_event("update_balance", %{"account_id" => account_id, "amount" => amount}, socket) do
    amount_decimal = parse_currency(amount)
    account = Finance.get_account!(account_id)

    # Convertir a USD
    {:ok, amount_usd} = ExchangeRateService.convert_to_usd(amount_decimal, account.currency)

    # Si es liability, hacer negativo
    amount_usd =
      if account.type == :liability do
        Decimal.negate(Decimal.abs(amount_usd))
      else
        amount_usd
      end

    balances =
      Map.put(socket.assigns.balances, account_id, %{
        amount_nominal: amount_decimal,
        amount_usd: amount_usd
      })

    {:noreply, assign(socket, :balances, balances)}
  end

  def handle_event("update_liability_detail", params, socket) do
    %{"account_id" => account_id, "current" => current, "future" => future} = params

    current_dec = parse_currency(current)
    future_dec = parse_currency(future)
    total = Decimal.add(current_dec, future_dec)

    details =
      Map.put(socket.assigns.liability_details, account_id, %{
        current_period_balance: current_dec,
        future_installments_balance: future_dec,
        total_debt: total
      })

    # Actualizar también el balance con el total
    account = Finance.get_account!(account_id)
    {:ok, total_usd} = ExchangeRateService.convert_to_usd(total, account.currency)

    balances =
      Map.put(socket.assigns.balances, account_id, %{
        amount_nominal: total,
        amount_usd: Decimal.negate(Decimal.abs(total_usd))
      })

    {:noreply,
     socket
     |> assign(:liability_details, details)
     |> assign(:balances, balances)}
  end

  def handle_event("toggle_flows", %{"value" => value}, socket) do
    has_flows = value == "true"
    {:noreply, assign(socket, :has_new_flows, has_flows)}
  end

  def handle_event("add_flow", _, socket) do
    amount = parse_currency(socket.assigns.flow_amount)
    direction = socket.assigns.flow_direction

    if Decimal.positive?(amount) do
      flow = %{
        amount_usd: amount,
        direction: direction,
        id: System.unique_integer([:positive])
      }

      {:noreply,
       socket
       |> assign(:flows, socket.assigns.flows ++ [flow])
       |> assign(:flow_amount, "")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_flow", %{"id" => id}, socket) do
    id = String.to_integer(id)
    flows = Enum.reject(socket.assigns.flows, &(&1.id == id))
    {:noreply, assign(socket, :flows, flows)}
  end

  def handle_event("update_flow_amount", %{"value" => value}, socket) do
    {:noreply, assign(socket, :flow_amount, value)}
  end

  def handle_event("update_flow_direction", %{"value" => value}, socket) do
    direction = String.to_existing_atom(value)
    {:noreply, assign(socket, :flow_direction, direction)}
  end

  def handle_event("update_income", %{"value" => value, "currency" => currency}, socket) do
    socket =
      case currency do
        "ARS" -> assign(socket, :income_ars, value)
        "USD" -> assign(socket, :income_usd, value)
        _ -> socket
      end

    # Calcular total en USD
    ars = parse_currency(socket.assigns.income_ars)
    usd = parse_currency(socket.assigns.income_usd)
    blue = socket.assigns.dolar_blue || Decimal.new(1)

    ars_in_usd =
      if Decimal.positive?(blue) do
        Decimal.div(ars, blue) |> Decimal.round(2)
      else
        Decimal.new(0)
      end

    total_usd = Decimal.add(usd, ars_in_usd)
    {:noreply, assign(socket, :income, Decimal.to_string(total_usd))}
  end

  # Fallback para evento sin currency (compatibilidad)
  def handle_event("update_income", %{"value" => value}, socket) do
    {:noreply, assign(socket, :income, value)}
  end

  def handle_event("confirm_closure", _, socket) do
    snapshot = socket.assigns.snapshot
    result = socket.assigns.result

    # Preparar datos para commit atómico
    balances_list =
      Enum.map(socket.assigns.balances, fn {account_id, balance_data} ->
        %{
          account_id: account_id,
          amount_nominal: balance_data.amount_nominal,
          amount_usd: balance_data.amount_usd
        }
      end)

    closure_data = %{
      balances: balances_list,
      liability_details: socket.assigns.liability_details,
      flows: socket.assigns.flows,
      result: result,
      exchange_rates: %{
        blue: socket.assigns.dolar_blue,
        mep: socket.assigns.dolar_mep
      }
    }

    # Commit atómico - TODO o NADA
    case Finance.commit_closure_atomic(snapshot, closure_data) do
      {:ok, _results} ->
        {:noreply,
         socket
         |> put_flash(:info, "¡Cierre completado!")
         |> push_navigate(to: ~p"/")}

      {:error, failed_operation, _failed_value, _changes_so_far} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error al guardar: #{failed_operation}")}
    end
  end

  defp maybe_calculate_result(%{assigns: %{current_step: :result}} = socket) do
    income = parse_currency(socket.assigns.income)

    # Calcular en memoria SIN persistir datos
    result =
      Finance.calculate_snapshot_preview(
        socket.assigns.balances,
        socket.assigns.flows,
        income,
        socket.assigns.previous_snapshot
      )

    assign(socket, :result, result)
  end

  defp maybe_calculate_result(socket), do: socket

  # parse_currency imported from NumberHelpers

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-6">
      <!-- Progress Steps -->
      <div class="flex justify-between items-center mb-8 px-4">
        <%= for {step, index} <- Enum.with_index(@steps) do %>
          <div class={"stepper-step #{step_class(index, @step_index)}"}>
            <div class="stepper-dot"></div>
            <span class="text-xs text-base-content/50 hidden sm:block">
              <%= step_label(step) %>
            </span>
          </div>
          <%= if index < length(@steps) - 1 do %>
            <div class={"flex-1 h-0.5 mx-2 #{if index < @step_index, do: "bg-success", else: "bg-base-300"}"}></div>
          <% end %>
        <% end %>
      </div>

      <!-- Step Content -->
      <div class="animate-fade-in">
        <%= case @current_step do %>
          <% :rates -> %>
            <.step_rates
              loading={@loading_rates}
              dolar_blue={@dolar_blue}
              dolar_mep={@dolar_mep}
            />

          <% :assets -> %>
            <.step_assets
              accounts={filter_by_types(@accounts, [:liquid, :investment])}
              balances={@balances}
              assets_filter={@assets_filter}
            />

          <% :liabilities -> %>
            <.step_liabilities
              accounts={filter_by_types(@accounts, [:liability])}
              balances={@balances}
              liability_details={@liability_details}
            />

          <% :flows -> %>
            <.step_flows
              has_new_flows={@has_new_flows}
              flows={@flows}
              flow_amount={@flow_amount}
              flow_direction={@flow_direction}
            />

          <% :income -> %>
            <.step_income
              income={@income}
              income_ars={@income_ars}
              income_usd={@income_usd}
              dolar_blue={@dolar_blue}
            />

          <% :result -> %>
            <.step_result result={@result} snapshot={@snapshot} />
        <% end %>
      </div>

      <!-- Navigation Buttons -->
      <div class="flex gap-3 mt-8">
        <%= if @step_index > 0 do %>
          <button phx-click="prev_step" class="btn btn-ghost flex-1 touch-target">
            <span class="hero-arrow-left mr-2"></span>
            Anterior
          </button>
        <% else %>
          <div class="flex-1"></div>
        <% end %>

        <%= if @current_step == :result do %>
          <button
            phx-click="confirm_closure"
            class="btn btn-primary flex-1 touch-target"
            disabled={is_nil(@result)}
          >
            <span class="hero-check-circle mr-2"></span>
            Confirmar Cierre
          </button>
        <% else %>
          <button
            phx-click="next_step"
            class="btn btn-primary flex-1 touch-target"
            disabled={@current_step == :rates and @loading_rates}
          >
            Siguiente
            <span class="hero-arrow-right ml-2"></span>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  # Step Components

  defp step_rates(assigns) do
    ~H"""
    <div class="text-center">
      <h2 class="text-2xl font-bold mb-2">Cierre de Mes</h2>
      <p class="text-base-content/60 mb-8">Vamos a actualizar tus saldos y calcular tu progreso.</p>

      <%= if @loading do %>
        <div class="flex flex-col items-center py-12">
          <span class="loading loading-spinner loading-lg mb-4"></span>
          <p class="text-base-content/60">Preparando todo...</p>
        </div>
      <% else %>
        <div class="text-left space-y-3">
          <div class="flex items-center gap-3 text-base-content/70">
            <span class="hero-check-circle text-success"></span>
            <span>Actualizaremos tus cuentas y deudas</span>
          </div>
          <div class="flex items-center gap-3 text-base-content/70">
            <span class="hero-check-circle text-success"></span>
            <span>Calcularemos cuánto ahorraste</span>
          </div>
          <div class="flex items-center gap-3 text-base-content/70">
            <span class="hero-check-circle text-success"></span>
            <span>Verás el rendimiento de tus inversiones</span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp step_assets(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2">Activos</h2>
      <p class="text-base-content/60 mb-4">Actualizá los saldos de tus cuentas e inversiones.</p>

      <!-- Toggle de tipo -->
      <div class="account-toggle account-toggle-2 mb-6">
        <div class="account-toggle-pill" style={"transform: translateX(#{if @assets_filter == :liquid, do: "0%", else: "100%"});"}></div>
        <button
          phx-click="change_assets_filter"
          phx-value-type="liquid"
          class={"account-toggle-option #{if @assets_filter == :liquid, do: "active"}"}
        >
          <span class="hero-banknotes text-lg"></span>
          <span>Líquidas</span>
        </button>
        <button
          phx-click="change_assets_filter"
          phx-value-type="investment"
          class={"account-toggle-option #{if @assets_filter == :investment, do: "active"}"}
        >
          <span class="hero-chart-bar text-lg"></span>
          <span>Inversiones</span>
        </button>
      </div>

      <% filtered_accounts = Enum.filter(@accounts, & &1.type == @assets_filter) %>

      <%= if Enum.empty?(filtered_accounts) do %>
        <div class="text-center py-8 text-base-content/60">
          <p>No tenés <%= if @assets_filter == :liquid, do: "cuentas líquidas", else: "inversiones" %>.</p>
          <.link navigate={~p"/cuentas"} class="btn btn-outline btn-sm mt-4">
            Agregar Cuentas
          </.link>
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for account <- filtered_accounts do %>
            <div class="card-zen p-4">
              <div class="flex items-center gap-3 mb-3">
                <div class={"w-10 h-10 rounded-full flex items-center justify-center #{account_bg_class(account.type)}"}
                >
                  <span class={"text-lg #{account_icon(account.type)}"}></span>
                </div>
                <div>
                  <p class="font-medium"><%= account.name %></p>
                  <p class="text-xs text-base-content/50"><%= account.currency %></p>
                </div>
              </div>
              <input
                type="tel"
                inputmode="decimal"
                placeholder="0"
                value={get_balance_amount(@balances, account.id)}
                phx-blur="update_balance"
                phx-value-account_id={account.id}
                phx-value-amount={get_balance_amount(@balances, account.id)}
                class="input input-bordered input-currency w-full"
              />
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp step_liabilities(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2">Pasivos</h2>
      <p class="text-base-content/60 mb-6">
        Mirá el resumen de tu tarjeta y anotá cuánto debés.
      </p>

      <%= if Enum.empty?(@accounts) do %>
        <div class="text-center py-8 text-base-content/60">
          <span class="hero-check-circle text-4xl text-success mb-2 block"></span>
          <p>¡No tenés deudas registradas!</p>
        </div>
      <% else %>
        <% grouped = Enum.group_by(@accounts, & &1.name) %>
        <div class="space-y-6">
          <%= for {name, group} <- grouped do %>
            <div class="card-zen p-5 border-error/20">
              <div class="flex items-center gap-3 mb-4">
                <div class="w-10 h-10 rounded-full bg-error/10 flex items-center justify-center">
                  <span class="hero-credit-card text-lg text-error"></span>
                </div>
                <div>
                  <p class="font-bold text-lg"><%= name %></p>
                  <div class="flex gap-1">
                    <%= for acc <- group do %>
                      <span class="badge badge-xs badge-ghost"><%= acc.currency %></span>
                    <% end %>
                  </div>
                </div>
              </div>

              <div class="space-y-6">
                <%= for account <- group do %>
                  <div class={if length(group) > 1, do: "pt-4 border-t border-error/10", else: ""}>
                    <%= if length(group) > 1 do %>
                      <p class="text-xs font-bold text-base-content/40 uppercase mb-3"><%= account.currency %></p>
                    <% end %>
                    <div class="grid grid-cols-2 gap-3">
                      <div>
                        <label class="text-xs text-base-content/50 mb-1 block">Consumo Actual</label>
                        <div class="relative">
                          <input
                            type="tel"
                            inputmode="decimal"
                            placeholder="0"
                            value={get_liability_current(@liability_details, account.id)}
                            phx-blur="update_liability_detail"
                            phx-value-account_id={account.id}
                            phx-value-current={get_liability_current(@liability_details, account.id)}
                            phx-value-future={get_liability_future(@liability_details, account.id)}
                            class="input input-bordered w-full text-right font-mono-numbers pr-14"
                          />
                          <span class="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/30 text-xs font-bold"><%= account.currency %></span>
                        </div>
                      </div>
                      <div>
                        <label class="text-xs text-base-content/50 mb-1 block">Cuotas Futuras</label>
                        <div class="relative">
                          <input
                            type="tel"
                            inputmode="decimal"
                            placeholder="0"
                            value={get_liability_future(@liability_details, account.id)}
                            phx-blur="update_liability_detail"
                            phx-value-account_id={account.id}
                            phx-value-current={get_liability_current(@liability_details, account.id)}
                            phx-value-future={get_liability_future(@liability_details, account.id)}
                            class="input input-bordered w-full text-right font-mono-numbers pr-14"
                          />
                          <span class="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/30 text-xs font-bold"><%= account.currency %></span>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp step_flows(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2">Flujos de Inversión</h2>
      <p class="text-base-content/60 mb-6">
        ¿Pusiste o sacaste plata de tus inversiones este mes?
      </p>

      <div class="flex gap-4 mb-6">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            type="radio"
            name="has_flows"
            value="false"
            checked={not @has_new_flows}
            phx-click="toggle_flows"
            class="radio"
          />
          <span>No</span>
        </label>
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            type="radio"
            name="has_flows"
            value="true"
            checked={@has_new_flows}
            phx-click="toggle_flows"
            class="radio"
          />
          <span>Sí</span>
        </label>
      </div>

      <%= if @has_new_flows do %>
        <div class="card-zen p-4 mb-4">
          <div class="space-y-3">
            <div>
              <label class="text-xs text-base-content/50 mb-1 block">Tipo de movimiento</label>
              <select
                phx-change="update_flow_direction"
                class="select select-bordered w-full"
              >
                <option value="deposit" selected={@flow_direction == :deposit}>Depósito (puse plata)</option>
                <option value="withdrawal" selected={@flow_direction == :withdrawal}>Retiro (saqué plata)</option>
              </select>
            </div>
            <div>
              <label class="text-xs text-base-content/50 mb-1 block">Monto en USD</label>
              <input
                type="tel"
                inputmode="decimal"
                placeholder="0"
                value={@flow_amount}
                phx-keyup="update_flow_amount"
                class="input input-bordered w-full text-xl font-mono-numbers"
              />
            </div>
            <button phx-click="add_flow" class="btn btn-primary w-full">
              <span class="hero-plus mr-1"></span>
              Agregar Flujo
            </button>
          </div>
        </div>

        <!-- Lista de flujos -->
        <%= if length(@flows) > 0 do %>
          <div class="space-y-2">
            <%= for flow <- @flows do %>
              <div class="card-zen p-3 flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <div class={"w-8 h-8 rounded-full flex items-center justify-center #{if flow.direction == :deposit, do: "bg-success/10", else: "bg-warning/10"}"}>
                    <span class={"text-sm #{if flow.direction == :deposit, do: "hero-arrow-down text-success", else: "hero-arrow-up text-warning"}"}></span>
                  </div>
                  <div>
                    <p class="font-medium font-mono-numbers">
                      US$ <%= format_decimal(flow.amount_usd) %>
                    </p>
                    <p class="text-xs text-base-content/50">
                      <%= if flow.direction == :deposit, do: "Depósito", else: "Retiro" %>
                    </p>
                  </div>
                </div>
                <button
                  phx-click="remove_flow"
                  phx-value-id={flow.id}
                  class="btn btn-ghost btn-circle btn-sm"
                >
                  <span class="hero-x-mark"></span>
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp step_income(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2">Ingresos</h2>
      <p class="text-base-content/60 mb-6">¿Cuánto ganaste este mes?</p>

      <div class="card-zen p-5 space-y-4">
        <div>
          <label class="text-xs text-base-content/50 mb-1 block uppercase tracking-wider font-bold">Ingresos en Pesos</label>
          <div class="relative">
            <input
              type="tel"
              inputmode="decimal"
              placeholder="0"
              value={@income_ars}
              phx-blur="update_income"
              phx-value-currency="ARS"
              class="input input-bordered w-full text-xl font-mono-numbers text-right pr-16"
            />
            <span class="absolute right-4 top-1/2 -translate-y-1/2 text-base-content/30 font-bold">ARS</span>
          </div>
        </div>

        <div>
          <label class="text-xs text-base-content/50 mb-1 block uppercase tracking-wider font-bold">Ingresos en Dólares</label>
          <div class="relative">
            <input
              type="tel"
              inputmode="decimal"
              placeholder="0"
              value={@income_usd}
              phx-blur="update_income"
              phx-value-currency="USD"
              class="input input-bordered w-full text-xl font-mono-numbers text-right pr-16"
            />
            <span class="absolute right-4 top-1/2 -translate-y-1/2 text-base-content/30 font-bold">USD</span>
          </div>
        </div>

        <div class="pt-4 border-t border-base-content/10">
          <div class="flex justify-between items-center">
            <span class="text-sm text-base-content/60">Total en USD</span>
            <span class="text-2xl font-mono-numbers font-bold text-primary">
              US$ <%= format_decimal(parse_currency(@income)) %>
            </span>
          </div>
          <%= if Decimal.positive?(parse_currency(@income_ars)) and @dolar_blue do %>
            <p class="text-xs text-base-content/40 text-right mt-1">
              Convertido a dólar blue ($<%= format_rate(@dolar_blue) %>)
            </p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp step_result(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2 text-center">Tu Score del Mes</h2>
      <p class="text-base-content/60 mb-6 text-center">
        <%= format_month(@snapshot.month) %> <%= @snapshot.year %>
      </p>

      <%= if @result do %>
        <div class="score-card mb-6">
          <p class="text-sm text-base-content/60 text-center mb-1">Patrimonio Neto</p>
          <p class="net-worth-display text-center mb-6">
            US$ <%= format_decimal(@result.total_net_worth_usd) %>
          </p>

          <div class="grid grid-cols-2 gap-4 mb-4">
            <div class="bg-savings rounded-lg p-4 text-center">
              <p class="text-xs text-base-content/60 mb-1">Ahorro Real</p>
              <p class="text-2xl font-mono-numbers font-bold text-savings">
                <%= format_signed(@result.total_savings_usd) %>
              </p>
            </div>
            <div class="bg-yield rounded-lg p-4 text-center">
              <p class="text-xs text-base-content/60 mb-1">Rendimiento</p>
              <p class="text-2xl font-mono-numbers font-bold text-yield">
                <%= format_signed(@result.total_yield_usd) %>
              </p>
            </div>
          </div>

          <div class="border-t border-base-300 pt-4 mt-4">
            <div class="flex justify-between text-sm mb-2">
              <span class="text-base-content/60">Ingreso</span>
              <span class="font-mono-numbers">US$ <%= format_decimal(@result.total_income_usd) %></span>
            </div>
            <div class="flex justify-between text-sm mb-2">
              <span class="text-base-content/60">Gastos de Vida</span>
              <span class="font-mono-numbers text-error">-US$ <%= format_decimal(Decimal.abs(@result.expenses)) %></span>
            </div>
            <div class="flex justify-between text-sm">
              <span class="text-base-content/60">Variación Patrimonial</span>
              <span class="font-mono-numbers"><%= format_signed(@result.delta_nw) %></span>
            </div>
          </div>
        </div>

        <div class="alert">
          <span class="hero-light-bulb text-warning"></span>
          <div class="text-sm">
            <p class="font-medium">¿Cómo leer esto?</p>
            <p class="text-base-content/70">
              <strong>Ahorro</strong> = Lo que guardaste de tu sueldo.<br/>
              <strong>Rendimiento</strong> = Lo que ganaron/perdieron tus inversiones.
            </p>
          </div>
        </div>
      <% else %>
        <div class="flex justify-center py-12">
          <span class="loading loading-spinner loading-lg"></span>
        </div>
      <% end %>
    </div>
    """
  end

  # Helpers

  defp step_class(index, current) when index < current, do: "completed"
  defp step_class(index, current) when index == current, do: "active"
  defp step_class(_, _), do: ""

  defp step_label(:rates), do: "Cotización"
  defp step_label(:assets), do: "Activos"
  defp step_label(:liabilities), do: "Pasivos"
  defp step_label(:flows), do: "Flujos"
  defp step_label(:income), do: "Ingresos"
  defp step_label(:result), do: "Resultado"

  defp filter_by_types(accounts, types) do
    Enum.filter(accounts, &(&1.type in types))
  end

  defp get_balance_amount(balances, account_id) do
    case Map.get(balances, account_id) do
      %{amount_nominal: amount} -> format_smart_currency(amount)
      _ -> ""
    end
  end

  defp get_liability_current(details, account_id) do
    case Map.get(details, account_id) do
      %{current_period_balance: amount} -> amount |> Decimal.to_string() |> String.replace(".", ",")
      _ -> ""
    end
  end

  defp get_liability_future(details, account_id) do
    case Map.get(details, account_id) do
      %{future_installments_balance: amount} -> amount |> Decimal.to_string() |> String.replace(".", ",")
      _ -> ""
    end
  end

  # format functions delegated to NumberHelpers
  # Using wrapper to maintain existing function name in templates
  defp format_decimal(nil), do: "0"
  defp format_decimal(decimal), do: format_currency(decimal, [])

  defp format_month(month) do
    months = ~w(Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre Octubre Noviembre Diciembre)
    Enum.at(months, month - 1)
  end

  defp account_bg_class(:liquid), do: "bg-primary/10"
  defp account_bg_class(:investment), do: "bg-accent/10"
  defp account_bg_class(:liability), do: "bg-error/10"

  defp account_icon(:liquid), do: "hero-banknotes"
  defp account_icon(:investment), do: "hero-chart-bar"
  defp account_icon(:liability), do: "hero-credit-card"

  # format_smart_currency imported from NumberHelpers
end
