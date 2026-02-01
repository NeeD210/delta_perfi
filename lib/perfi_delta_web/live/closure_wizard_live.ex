defmodule PerfiDeltaWeb.ClosureWizardLive do
  @moduledoc """
  El "Ritual de Cierre" - Wizard paso a paso para el cierre mensual.
  """
  use PerfiDeltaWeb, :live_view

  alias PerfiDelta.Finance
  alias PerfiDelta.Services.ExchangeRateService

  @steps [:rates, :assets, :liabilities, :flows, :income, :result]

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    # Obtener o crear snapshot draft para el mes actual
    {:ok, snapshot} = Finance.get_or_create_current_snapshot(user_id)
    accounts = Finance.list_accounts(user_id)

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
      |> assign(:balances, %{})
      |> assign(:liability_details, %{})
      |> assign(:flows, [])
      |> assign(:has_new_flows, false)
      |> assign(:flow_amount, "")
      |> assign(:flow_direction, :deposit)
      |> assign(:income, "")
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

  def handle_event("update_balance", %{"account_id" => account_id, "amount" => amount}, socket) do
    amount_decimal = parse_decimal(amount)
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

    current_dec = parse_decimal(current)
    future_dec = parse_decimal(future)
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
    amount = parse_decimal(socket.assigns.flow_amount)
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

  def handle_event("update_income", %{"value" => value}, socket) do
    {:noreply, assign(socket, :income, value)}
  end

  def handle_event("confirm_closure", _, socket) do
    _user_id = socket.assigns.current_scope.user.id
    snapshot = socket.assigns.snapshot
    result = socket.assigns.result

    # Guardar todos los balances
    Enum.each(socket.assigns.balances, fn {account_id, balance_data} ->
      Finance.upsert_balance(%{
        snapshot_id: snapshot.id,
        account_id: account_id,
        amount_nominal: balance_data.amount_nominal,
        amount_usd: balance_data.amount_usd
      })
    end)

    # Guardar detalles de liability
    Enum.each(socket.assigns.liability_details, fn {account_id, detail} ->
      # Obtener el balance correspondiente
      case Finance.upsert_balance(%{
             snapshot_id: snapshot.id,
             account_id: account_id,
             amount_nominal: detail.total_debt,
             amount_usd: socket.assigns.balances[account_id].amount_usd
           }) do
        {:ok, balance} ->
          Finance.upsert_liability_detail(balance.id, detail)

        _ ->
          nil
      end
    end)

    # Guardar flujos de inversión
    Enum.each(socket.assigns.flows, fn flow ->
      Finance.create_investment_flow(%{
        snapshot_id: snapshot.id,
        amount_usd: flow.amount_usd,
        direction: flow.direction
      })
    end)

    # Confirmar snapshot
    {:ok, _snapshot} =
      Finance.confirm_snapshot(snapshot, %{
        total_income_usd: result.total_income_usd,
        total_net_worth_usd: result.total_net_worth_usd,
        total_savings_usd: result.total_savings_usd,
        total_yield_usd: result.total_yield_usd,
        exchange_rate_blue: socket.assigns.dolar_blue,
        exchange_rate_mep: socket.assigns.dolar_mep
      })

    {:noreply,
     socket
     |> put_flash(:info, "¡Cierre completado!")
     |> push_navigate(to: ~p"/")}
  end

  defp maybe_calculate_result(%{assigns: %{current_step: :result}} = socket) do
    income = parse_decimal(socket.assigns.income)
    snapshot_id = socket.assigns.snapshot.id

    # Primero guardar los balances temporalmente para el cálculo
    Enum.each(socket.assigns.balances, fn {account_id, balance_data} ->
      Finance.upsert_balance(%{
        snapshot_id: snapshot_id,
        account_id: account_id,
        amount_nominal: balance_data.amount_nominal,
        amount_usd: balance_data.amount_usd
      })
    end)

    # Guardar flows temporalmente
    Enum.each(socket.assigns.flows, fn flow ->
      Finance.create_investment_flow(%{
        snapshot_id: snapshot_id,
        amount_usd: flow.amount_usd,
        direction: flow.direction
      })
    end)

    # Calcular
    result = Finance.calculate_snapshot_values(snapshot_id, income)
    assign(socket, :result, result)
  end

  defp maybe_calculate_result(socket), do: socket

  defp parse_decimal(""), do: Decimal.new(0)
  defp parse_decimal(nil), do: Decimal.new(0)

  defp parse_decimal(str) when is_binary(str) do
    if String.contains?(str, ",") do
      str
      |> String.replace(".", "")
      |> String.replace(",", ".")
      |> Decimal.new()
    else
      Decimal.new(str)
    end
  rescue
    _ -> Decimal.new(0)
  end

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
            <.step_income income={@income} dolar_blue={@dolar_blue} />

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
      <h2 class="text-2xl font-bold mb-2">Cotizaciones del Día</h2>
      <p class="text-base-content/60 mb-8">Obteniendo las cotizaciones actuales...</p>

      <%= if @loading do %>
        <div class="flex justify-center py-12">
          <span class="loading loading-spinner loading-lg"></span>
        </div>
      <% else %>
        <div class="grid grid-cols-2 gap-4">
          <div class="card-zen p-6">
            <p class="text-sm text-base-content/60 mb-1">Dólar Blue</p>
            <p class="text-3xl font-mono-numbers font-bold">
              $<%= format_rate(@dolar_blue) %>
            </p>
          </div>
          <div class="card-zen p-6">
            <p class="text-sm text-base-content/60 mb-1">Dólar MEP</p>
            <p class="text-3xl font-mono-numbers font-bold">
              $<%= format_rate(@dolar_mep) %>
            </p>
          </div>
        </div>

        <p class="text-xs text-base-content/40 mt-6">
          Usamos el Dólar Blue para convertir tus pesos a dólares.
        </p>
      <% end %>
    </div>
    """
  end

  defp step_assets(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2">Activos</h2>
      <p class="text-base-content/60 mb-6">Actualizá los saldos de tus cuentas e inversiones.</p>

      <%= if Enum.empty?(@accounts) do %>
        <div class="text-center py-8 text-base-content/60">
          <p>No tenés cuentas de activos.</p>
          <.link navigate={~p"/cuentas"} class="btn btn-outline btn-sm mt-4">
            Agregar Cuentas
          </.link>
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for account <- @accounts do %>
            <div class="card-zen p-4">
              <div class="flex items-center gap-3 mb-3">
                <div class={"w-10 h-10 rounded-full flex items-center justify-center #{account_bg_class(account.type)}"}>
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
      <p class="text-base-content/60 mb-2">El momento de la verdad.</p>
      <p class="text-sm text-base-content/50 mb-6">
        Mirá el resumen de tu tarjeta y anotá cuánto debés.
      </p>

      <%= if Enum.empty?(@accounts) do %>
        <div class="text-center py-8 text-base-content/60">
          <span class="hero-check-circle text-4xl text-success mb-2 block"></span>
          <p>¡No tenés deudas registradas!</p>
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for account <- @accounts do %>
            <div class="card-zen p-4 border-error/30">
              <div class="flex items-center gap-3 mb-4">
                <div class="w-10 h-10 rounded-full bg-error/10 flex items-center justify-center">
                  <span class="hero-credit-card text-lg text-error"></span>
                </div>
                <div>
                  <p class="font-medium"><%= account.name %></p>
                  <p class="text-xs text-base-content/50"><%= account.currency %></p>
                </div>
              </div>

              <div class="space-y-3">
                <div>
                  <label class="text-sm text-base-content/70 mb-1 block">
                    ¿Cuánto vence este mes?
                  </label>
                  <input
                    type="tel"
                    inputmode="decimal"
                    placeholder="Saldo del resumen"
                    value={get_liability_current(@liability_details, account.id)}
                    phx-blur="update_liability_detail"
                    phx-value-account_id={account.id}
                    phx-value-current={get_liability_current(@liability_details, account.id)}
                    phx-value-future={get_liability_future(@liability_details, account.id)}
                    class="input input-bordered input-currency w-full"
                  />
                </div>

                <div>
                  <label class="text-sm text-base-content/70 mb-1 block">
                    ¿Cuánto suman tus cuotas futuras?
                  </label>
                  <p class="text-xs text-base-content/40 mb-2">
                    Mirá el cuadro "Cuotas a Vencer" en tu resumen
                  </p>
                  <input
                    type="tel"
                    inputmode="decimal"
                    placeholder="Cuotas pendientes"
                    value={get_liability_future(@liability_details, account.id)}
                    phx-blur="update_liability_detail"
                    phx-value-account_id={account.id}
                    phx-value-current={get_liability_current(@liability_details, account.id)}
                    phx-value-future={get_liability_future(@liability_details, account.id)}
                    class="input input-bordered input-currency w-full"
                  />
                </div>

                <!-- Total -->
                <%= if detail = Map.get(@liability_details, account.id) do %>
                  <div class="bg-error/10 rounded-lg p-3 mt-2">
                    <p class="text-sm text-base-content/70">Deuda Total</p>
                    <p class="text-xl font-mono-numbers font-bold text-error">
                      -$<%= format_decimal(detail.total_debt) %>
                    </p>
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
          <div class="flex gap-2 mb-3">
            <select
              phx-change="update_flow_direction"
              class="select select-bordered flex-shrink-0"
            >
              <option value="deposit" selected={@flow_direction == :deposit}>Depósito</option>
              <option value="withdrawal" selected={@flow_direction == :withdrawal}>Retiro</option>
            </select>
            <input
              type="tel"
              inputmode="decimal"
              placeholder="Monto en USD"
              value={@flow_amount}
              phx-keyup="update_flow_amount"
              class="input input-bordered flex-1"
            />
          </div>
          <button phx-click="add_flow" class="btn btn-outline btn-sm w-full">
            <span class="hero-plus mr-1"></span>
            Agregar Flujo
          </button>
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

      <div class="card-zen p-4">
        <label class="text-sm text-base-content/70 mb-2 block">
          Ingreso total del mes (en USD)
        </label>
        <p class="text-xs text-base-content/40 mb-3">
          Sueldo + extras. Si cobrás en pesos, convertí usando el dólar blue ($<%= format_rate(@dolar_blue) %>)
        </p>
        <input
          type="tel"
          inputmode="decimal"
          placeholder="0"
          value={@income}
          phx-keyup="update_income"
          class="input input-bordered input-currency w-full text-2xl"
        />
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
      %{amount_nominal: amount} -> amount |> Decimal.to_string() |> String.replace(".", ",")
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

  defp format_rate(nil), do: "-"
  defp format_rate(rate), do: Decimal.round(rate, 0) |> Decimal.to_string()

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

  defp add_thousands_separator(str) do
    str
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(".")
    |> String.reverse()
  end

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
end
