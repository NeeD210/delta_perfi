defmodule PerfiDeltaWeb.AccountsLive do
  use PerfiDeltaWeb, :live_view

  alias PerfiDelta.Finance
  alias PerfiDelta.Finance.FinancialAccount
  import PerfiDeltaWeb.Helpers.NumberHelpers, only: [format_currency: 2, add_thousands_separator: 1]

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    accounts = Finance.list_accounts_with_latest_balances(user_id)

    socket =
      socket
      |> assign(:page_title, "Cuentas")
      |> assign(:accounts, accounts)
      |> assign(:filter_type, :liquid)
      |> assign(:show_form, false)
      |> assign(:editing_account, nil)
      |> assign(:balance_history, [])
      |> assign(:form, to_form(Finance.change_account(%FinancialAccount{})))

    {:ok, socket}
  end

  @impl true
  def handle_event("show_form", %{"type" => type}, socket) do
    changeset = Finance.change_account(%FinancialAccount{}, %{type: type})

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_account, nil)
     |> assign(:balance_history, [])
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("hide_form", _, socket) do
    {:noreply, assign(socket, :show_form, false)}
  end

  def handle_event("change_filter", %{"type" => type}, socket) do
    filter_type = String.to_existing_atom(type)
    {:noreply, assign(socket, :filter_type, filter_type)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    account = Finance.get_account!(id)
    changeset = Finance.change_account(account)
    history = Finance.list_balance_history(account.id)

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_account, account)
     |> assign(:balance_history, history)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("validate", %{"financial_account" => params}, socket) do
    account = socket.assigns.editing_account || %FinancialAccount{}

    user_id = socket.assigns.current_scope.user.id
    params = Map.put(params, "user_id", user_id)

    changeset =
      account
      |> Finance.change_account(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"financial_account" => params}, socket) do
    user_id = socket.assigns.current_scope.user.id
    params = Map.put(params, "user_id", user_id)

    result =
      if socket.assigns.editing_account do
        Finance.update_account(socket.assigns.editing_account, params)
      else
        Finance.create_account(params)
      end

    case result do
      {:ok, _account} ->
        accounts = Finance.list_accounts_with_latest_balances(user_id)

        {:noreply,
         socket
         |> assign(:accounts, accounts)
         |> assign(:show_form, false)
         |> put_flash(:info, "Cuenta guardada")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    account = Finance.get_account!(id)
    {:ok, _} = Finance.delete_account(account)

    user_id = socket.assigns.current_scope.user.id
    accounts = Finance.list_accounts_with_latest_balances(user_id)

    {:noreply,
     socket
     |> assign(:accounts, accounts)
     |> put_flash(:info, "Cuenta eliminada")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-6">
      <!-- Header con título y total -->
      <div class="flex items-center justify-between mb-6 animate-fade-in">
        <h1 class="text-2xl font-bold text-gradient-hero">Tus Cuentas</h1>
        <div class="glass-card-static px-4 py-2">
          <span class="text-lg font-mono-numbers font-bold">
            <%= format_usd_compact(sum_by_type(@accounts, @filter_type)) %>
          </span>
        </div>
      </div>

      <!-- Toggle de filtro por tipo -->
      <div class="account-toggle mb-6">
        <div class="account-toggle-pill" style={"transform: translateX(#{account_toggle_transform(@filter_type)});"}></div>
        <button
          phx-click="change_filter"
          phx-value-type="liquid"
          class={"account-toggle-option #{if @filter_type == :liquid, do: "active"}"}
        >
          <span class="hero-banknotes text-lg"></span>
          <span>Líquidas</span>
        </button>
        <button
          phx-click="change_filter"
          phx-value-type="investment"
          class={"account-toggle-option #{if @filter_type == :investment, do: "active"}"}
        >
          <span class="hero-chart-bar text-lg"></span>
          <span>Inversiones</span>
        </button>
        <button
          phx-click="change_filter"
          phx-value-type="liability"
          class={"account-toggle-option #{if @filter_type == :liability, do: "active"}"}
        >
          <span class="hero-credit-card text-lg"></span>
          <span>Deudas</span>
        </button>
      </div>



      <!-- Modal/Form -->
      <%= if @show_form do %>
        <div class="fixed inset-0 z-[60] flex items-center justify-center p-4">
          <div class="absolute inset-0 bg-black/40 backdrop-blur-sm" phx-click="hide_form"></div>
          <div class="glass-card relative z-10 w-full max-w-md px-4 py-6 animate-scale-in max-h-[85vh] overflow-y-auto">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-bold text-gradient-hero">
                <%= if @editing_account, do: "Editar Cuenta", else: "Nueva Cuenta" %>
              </h2>
              <button phx-click="hide_form" class="btn btn-ghost btn-circle btn-sm btn-glass">
                <span class="hero-x-mark"></span>
              </button>
            </div>

            <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text font-medium">Nombre</span>
                </label>
                <input
                  type="text"
                  name={@form[:name].name}
                  value={@form[:name].value}
                  placeholder="Ej: Banco Galicia, Binance BTC"
                  class="input input-bordered input-glass w-full"
                  id="account-name-input"
                  phx-hook="Focus"
                  required
                />
                <%= if @form[:name].errors != [] do %>
                  <label class="label">
                    <span class="label-text-alt text-debt">
                      <%= elem(hd(@form[:name].errors), 0) %>
                    </span>
                  </label>
                <% end %>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text font-medium">Tipo</span>
                </label>
                <select name={@form[:type].name} class="select select-bordered input-glass w-full">
                  <option value="liquid" selected={@form[:type].value == :liquid}>
                    Cuenta Líquida (Banco, Efectivo)
                  </option>
                  <option value="investment" selected={@form[:type].value == :investment}>
                    Inversión (Cripto, FCI, Acciones)
                  </option>
                  <option value="liability" selected={@form[:type].value == :liability}>
                    Deuda (Tarjeta de Crédito, Préstamo)
                  </option>
                </select>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text font-medium">Moneda</span>
                </label>
                <select name={@form[:currency].name} class="select select-bordered input-glass w-full">
                  <option value="ARS" selected={@form[:currency].value == "ARS"}>ARS - Peso Argentino</option>
                  <option value="USD" selected={@form[:currency].value == "USD"}>USD - Dólar</option>
                  <option value="USDT" selected={@form[:currency].value == "USDT"}>USDT - Tether</option>
                  <option value="BTC" selected={@form[:currency].value == "BTC"}>BTC - Bitcoin</option>
                  <option value="ETH" selected={@form[:currency].value == "ETH"}>ETH - Ethereum</option>
                  <option value="SOL" selected={@form[:currency].value == "SOL"}>SOL - Solana</option>
                </select>
              </div>

              <button type="submit" class="btn btn-primary w-full mt-4">
                Guardar
              </button>
            </.form>

            <!-- Balance History (solo al editar) -->
            <%= if @editing_account && length(@balance_history) > 0 do %>
              <div class="mt-6 pt-4 border-t border-gray-200/30">
                <h3 class="text-sm font-semibold opacity-60 mb-3">Historial de Balances</h3>
                <div class="space-y-2 max-h-40 overflow-y-auto">
                  <%= for balance <- @balance_history do %>
                    <div class="flex justify-between items-center text-sm py-2 px-3 rounded-lg bg-white/30">
                      <span class="opacity-60"><%= format_month(balance.month, balance.year) %></span>
                      <span class="font-mono-numbers font-semibold">
                        <%= format_balance_amount(balance.amount, @editing_account.currency) %>
                      </span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Delete button (solo al editar) -->
            <%= if @editing_account do %>
              <button 
                phx-click="delete" 
                phx-value-id={@editing_account.id}
                data-confirm="¿Eliminar esta cuenta y todo su historial?"
                class="btn btn-ghost w-full mt-4 text-debt hover:bg-debt/10"
              >
                <span class="hero-trash mr-2"></span>
                Eliminar Cuenta
              </button>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Lista de Cuentas filtrada -->
      <div class="space-y-3">
        <%= for {account, idx} <- Enum.with_index(filter_by_type(@accounts, @filter_type)) do %>
          <.account_card account={account} idx={idx} />
        <% end %>

        <!-- Skeleton de agregar cuenta -->
        <button
          phx-click="show_form"
          phx-value-type={Atom.to_string(@filter_type)}
          class={"glass-card p-4 w-full flex items-center justify-center gap-3 border-2 border-dashed transition-all hover:border-solid #{add_account_skeleton_class(@filter_type)}"}
        >
          <div class={"icon-badge icon-badge-#{@filter_type}"}>
            <span class="hero-plus"></span>
          </div>
          <span class="font-medium opacity-60">Agregar cuenta</span>
        </button>
      </div>
    </div>
    """
  end

  attr :account, :map, required: true
  attr :idx, :integer, default: 0

  defp account_card(assigns) do
    ~H"""
    <button 
      phx-click="edit" 
      phx-value-id={@account.id}
      class={"list-item-glass animate-fade-in stagger-#{min(@idx + 1, 5)} w-full text-left cursor-pointer hover:scale-[1.01] active:scale-[0.99] transition-transform"}
    >
      <div class={"icon-badge icon-badge-#{@account.type}"}>
        <span class={account_icon(@account.type)}></span>
      </div>
      <div class="flex-1 min-w-0">
        <p class="font-medium truncate"><%= @account.name %></p>
        <p class="text-xs opacity-50"><%= @account.currency %></p>
      </div>
      <div class="flex items-center gap-2">
        <span class={"font-mono-numbers font-semibold #{account_amount_class(@account.type)}"}>
          <%= format_account_balance(@account) %>
        </span>
        <span class="hero-chevron-right opacity-30"></span>
      </div>
    </button>
    """
  end

  # Helpers

  defp filter_by_type(accounts, type), do: Enum.filter(accounts, &(&1.type == type))

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

  defp format_usd_compact(decimal) do
    abs_value = Decimal.abs(decimal)
    is_negative = Decimal.negative?(decimal)
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

    "US$ #{prefix}#{formatted}"
  end

  defp format_account_balance(account) do
    case account.latest_balance do
      nil ->
        "-"

      balance ->
        case balance.amount_nominal do
          nil ->
            "-"

          amount ->
            formatted = format_currency(Decimal.abs(amount), [])
            prefix = if Decimal.negative?(amount), do: "-", else: ""
            "#{prefix}#{formatted}"
        end
    end
  end

  # format_currency and add_thousands_separator delegated to NumberHelpers via import

  defp account_icon(:liquid), do: "hero-banknotes"
  defp account_icon(:investment), do: "hero-chart-bar"
  defp account_icon(:liability), do: "hero-credit-card"

  defp add_account_skeleton_class(:liquid), do: "border-savings/30 hover:border-savings/60"
  defp add_account_skeleton_class(:investment), do: "border-yield/30 hover:border-yield/60"
  defp add_account_skeleton_class(:liability), do: "border-debt/30 hover:border-debt/60"

  defp account_amount_class(:liquid), do: "text-savings"
  defp account_amount_class(:investment), do: "text-yield"
  defp account_amount_class(:liability), do: "text-debt"

  @months ~w(Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic)
  defp format_month(month, year), do: "#{Enum.at(@months, month - 1)} #{year}"

  defp format_balance_amount(amount, currency) do
    formatted = 
      amount
      |> Decimal.abs()
      |> Decimal.round(2)
      |> Decimal.to_string()
      |> String.split(".")
      |> case do
        [int] -> add_thousands_separator(int)
        [int, dec] -> "#{add_thousands_separator(int)},#{String.pad_trailing(dec, 2, "0")}"
      end

    prefix = if Decimal.negative?(amount), do: "-", else: ""
    "#{prefix}#{currency} #{formatted}"
  end

  defp account_toggle_transform(:liquid), do: "0%"
  defp account_toggle_transform(:investment), do: "100%"
  defp account_toggle_transform(:liability), do: "200%"
end
