defmodule PerfiDeltaWeb.OnboardingLive do
  @moduledoc """
  Wizard de onboarding para configurar el primer snapshot.
  """
  use PerfiDeltaWeb, :live_view

  alias PerfiDelta.Accounts
  alias PerfiDelta.Finance
  alias PerfiDelta.Finance.FinancialAccount
  alias PerfiDelta.Services.ExchangeRateService
  import PerfiDeltaWeb.Helpers.NumberHelpers, only: [parse_currency: 1, format_currency: 1, add_thousands_separator: 1]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    accounts = if user, do: Finance.list_accounts(user.id), else: []

    # Cargar paso y datos guardados del usuario
    saved_step = user.onboarding_step || 1
    saved_data = user.onboarding_data || %{}

    # Restaurar balances (convertir keys de string a uuid)
    saved_balances = restore_balances(saved_data["balances"])
    saved_liability_details = restore_liability_details(saved_data["liability_details"])
    saved_preferences = restore_preferences(saved_data["preferences"])
    saved_income = restore_income(saved_data["income"])

    socket =
      socket
      |> assign(:page_title, "Setup Inicial")
      |> assign(:step, saved_step)
      |> assign(:accounts, accounts)
      |> assign(:balances, saved_balances)
      |> assign(:liability_details, saved_liability_details)
      |> assign(:show_form, false)
      |> assign(:form_type, nil)
      |> assign(:form, to_form(Finance.change_account(%FinancialAccount{})))
      |> assign(:dolar_blue, nil)
      |> assign(:loading, false)
      |> assign(:preferences, saved_preferences)
      |> assign(:income, saved_income)

    # Fetch dolar rate
    send(self(), :fetch_rate)

    {:ok, socket}
  end

  @impl true
  def handle_info(:fetch_rate, socket) do
    rate =
      case ExchangeRateService.fetch_dolar_blue() do
        {:ok, r} -> r
        _ -> nil
      end

    {:noreply, assign(socket, :dolar_blue, rate)}
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("next_step", _, socket) do
    step = socket.assigns.step
    preferences = socket.assigns.preferences

    next =
      case step do
        1 -> 2
        2 -> 3
        3 -> if(preferences.investments, do: 4, else: if(preferences.debts, do: 5, else: 6))
        4 -> if(preferences.debts, do: 5, else: 6)
        5 -> 6
        6 -> 7
        7 -> 8
        _ -> step
      end

    # Persistir el paso en la base de datos
    user = socket.assigns.current_scope.user
    Accounts.update_onboarding_step(user, next)

    socket =
      socket
      |> assign(:step, next)
      |> maybe_auto_show_form(next)

    {:noreply, socket}
  end

  def handle_event("prev_step", _, socket) do
    step = socket.assigns.step
    preferences = socket.assigns.preferences

    prev =
      case step do
        2 -> 1
        3 -> 2
        4 -> 3
        5 -> if(preferences.investments, do: 4, else: 3)
        6 -> if(preferences.debts, do: 5, else: if(preferences.investments, do: 4, else: 3))
        7 -> 6
        8 -> 7
        _ -> 1
      end

    # Persistir el paso en la base de datos
    user = socket.assigns.current_scope.user
    Accounts.update_onboarding_step(user, prev)

    {:noreply, assign(socket, :step, prev)}
  end

  def handle_event("toggle_preference", %{"type" => type}, socket) do
    type_atom = String.to_existing_atom(type)
    new_value = !Map.get(socket.assigns.preferences, type_atom)
    preferences = Map.put(socket.assigns.preferences, type_atom, new_value)
    socket = assign(socket, :preferences, preferences)
    persist_onboarding_data(socket)
    {:noreply, socket}
  end

  def handle_event("show_form", %{"type" => type}, socket) do
    type_atom = String.to_existing_atom(type)
    # Using a plain map for the form data since we need custom handling for currencies
    form_data = %{"name" => nil, "currencies" => [], "original_name" => nil}

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:form_type, type_atom)
     |> assign(:form, to_form(form_data))}
  end

  def handle_event("hide_form", _, socket) do
    {:noreply, assign(socket, :show_form, false)}
  end

  def handle_event("validate", %{"name" => _name, "currencies" => _currencies} = params, socket) do
    # Simple validation using Map
    # In a real app, maybe use a Schemaless Changeset
    {:noreply, assign(socket, :form, to_form(params))}
  end
  # Handle validate case where currencies might be missing from params if none selected (though usually hidden input helps or empty list)
  def handle_event("validate", params, socket) do
     {:noreply, assign(socket, :form, to_form(params))}
  end

  def handle_event("toggle_investment_preset", %{"name" => name, "currency" => currency}, socket) do
    type = :investment
    user_id = socket.assigns.current_scope.user.id

    # Check if exists
    existing = Enum.find(socket.assigns.accounts, fn acc ->
      acc.type == type and acc.name == name and acc.currency == currency
    end)

    accounts =
      if existing do
        # Toggle OFF: Delete
        Finance.delete_account(existing)
        Enum.reject(socket.assigns.accounts, &(&1.id == existing.id))
      else
        # Toggle ON: Create
        {:ok, account} = Finance.create_account(%{
          name: name,
          type: type,
          currency: currency,
          user_id: user_id
        })
        socket.assigns.accounts ++ [account]
      end

    {:noreply, assign(socket, :accounts, accounts)}
  end

  def handle_event("edit_account", %{"name" => name, "type" => type}, socket) do
    type_atom = String.to_existing_atom(type)

    # Find all accounts in this group
    group = Enum.filter(socket.assigns.accounts, &(&1.name == name and &1.type == type_atom))

    currencies = Enum.map(group, & &1.currency)

    form_data = %{
      "name" => name,
      "currencies" => currencies,
      "original_name" => name
    }

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:form_type, type_atom)
     |> assign(:form, to_form(form_data))}
  end

  def handle_event("save_account", %{"name" => name} = params, socket) do
    currencies = Map.get(params, "currencies", [])
    original_name = params["original_name"] || "" # Empty string if new
    type = socket.assigns.form_type
    user_id = socket.assigns.current_scope.user.id

    # Validate at least one currency
    if Enum.empty?(currencies) do
         {:noreply,
          socket
          |> put_flash(:error, "Seleccioná al menos una moneda")
          |> assign(:form, to_form(params))}
    else
      # Logic:
      # 1. Get current group (if editing)
      # 2. Identify Adds, Removes, Updates

      current_accounts =
        if original_name != "" do
          Enum.filter(socket.assigns.accounts, &(&1.name == original_name and &1.type == type))
        else
          []
        end

      current_currencies = Enum.map(current_accounts, & &1.currency)

      # REMOVES
      to_remove_currencies = current_currencies -- currencies
      enum_to_remove = Enum.filter(current_accounts, &(&1.currency in to_remove_currencies))

      Enum.each(enum_to_remove, fn account ->
        Finance.delete_account(account)
      end)

      # ADDS
      to_add_currencies = currencies -- current_currencies

      new_accounts =
        Enum.map(to_add_currencies, fn currency ->
           {:ok, acc} = Finance.create_account(%{
             name: name,
             type: type,
             currency: currency,
             user_id: user_id
           })
           acc
        end)

      # UPDATES (Name change)
      updated_accounts =
        if original_name != "" and name != original_name do
           to_update_currencies = current_currencies -- to_remove_currencies
           Enum.map(current_accounts, fn acc ->
             if acc.currency in to_update_currencies do
               {:ok, updated} = Finance.update_account(acc, %{name: name})
               updated
             else
               acc # Should be deleted already
             end
           end)
           |> Enum.filter(&(&1.currency in to_update_currencies))
        else
           Enum.reject(current_accounts, &(&1.currency in to_remove_currencies))
        end

      # Reconstruct accounts list assignment
      # Remove old group, add new/updated

      # Remove all from old group from state
      remaining_accounts = Enum.reject(socket.assigns.accounts, &(&1.name == original_name and &1.type == type))

      final_accounts = remaining_accounts ++ updated_accounts ++ new_accounts

      {:noreply,
       socket
       |> assign(:accounts, final_accounts)
       |> assign(:show_form, false)
       |> put_flash(:info, "Cuenta guardada")}
    end
  end

  def handle_event("delete_group", %{"name" => name, "type" => type}, socket) do
     type_atom = String.to_existing_atom(type)
     group = Enum.filter(socket.assigns.accounts, &(&1.name == name and &1.type == type_atom))

     Enum.each(group, &Finance.delete_account/1)

     remaining = Enum.reject(socket.assigns.accounts, &(&1.name == name and &1.type == type_atom))

     {:noreply, assign(socket, :accounts, remaining)}
  end

  def handle_event("update_balance", %{"account_id" => account_id, "value" => value}, socket) do
    amount = parse_currency(value)
    account = Enum.find(socket.assigns.accounts, &(&1.id == account_id))

    {:ok, amount_usd} = ExchangeRateService.convert_to_usd(amount, account.currency)

    amount_usd =
      if account.type == :liability do
        Decimal.negate(Decimal.abs(amount_usd))
      else
        amount_usd
      end

    balances =
      Map.put(socket.assigns.balances, account_id, %{
        amount_nominal: amount,
        amount_usd: amount_usd
      })

    socket = assign(socket, :balances, balances)
    persist_onboarding_data(socket)
    {:noreply, socket}
  end

  def handle_event("update_liability", %{"account_id" => account_id, "field" => field, "value" => value}, socket) do
    # Obtener detalles existentes o iniciales
    default = %{current_period_balance: Decimal.new(0), future_installments_balance: Decimal.new(0)}
    existing = Map.get(socket.assigns.liability_details, account_id, default)

    amount = parse_currency(value)

    # Actualizar solo el campo que cambió
    new_details =
      case field do
        "current" -> %{existing | current_period_balance: amount}
        "future" -> %{existing | future_installments_balance: amount}
        _ -> existing
      end

    total = Decimal.add(new_details.current_period_balance, new_details.future_installments_balance)
    new_details = Map.put(new_details, :total_debt, total)

    details = Map.put(socket.assigns.liability_details, account_id, new_details)

    account = Enum.find(socket.assigns.accounts, &(&1.id == account_id))
    {:ok, total_usd} = ExchangeRateService.convert_to_usd(total, account.currency)

    balances =
      Map.put(socket.assigns.balances, account_id, %{
        amount_nominal: total,
        amount_usd: Decimal.negate(Decimal.abs(total_usd))
      })

    socket =
     socket
     |> assign(:liability_details, details)
     |> assign(:balances, balances)
    
    persist_onboarding_data(socket)
    {:noreply, socket}
  end

  def handle_event("update_income", %{"currency" => "ARS", "value" => value}, socket) do
    ars = parse_currency(value)
    usd = socket.assigns.income.usd
    
    {:ok, ars_in_usd} = ExchangeRateService.convert_to_usd(ars, "ARS")
    total_usd = Decimal.add(ars_in_usd, usd)
    
    income = %{socket.assigns.income | ars: ars, total_usd: total_usd}
    socket = assign(socket, :income, income)
    persist_onboarding_data(socket)
    {:noreply, socket}
  end

  def handle_event("update_income", %{"currency" => "USD", "value" => value}, socket) do
    usd = parse_currency(value)
    ars = socket.assigns.income.ars
    
    {:ok, ars_in_usd} = ExchangeRateService.convert_to_usd(ars, "ARS")
    total_usd = Decimal.add(ars_in_usd, usd)
    
    income = %{socket.assigns.income | usd: usd, total_usd: total_usd}
    socket = assign(socket, :income, income)
    persist_onboarding_data(socket)
    {:noreply, socket}
  end

  def handle_event("complete_onboarding", _, socket) do
    user_id = socket.assigns.current_scope.user.id

    # Crear snapshot inicial
    {:ok, snapshot} = Finance.get_or_create_current_snapshot(user_id)

    # Guardar balances
    Enum.each(socket.assigns.balances, fn {account_id, balance} ->
      Finance.upsert_balance(%{
        snapshot_id: snapshot.id,
        account_id: account_id,
        amount_nominal: balance.amount_nominal,
        amount_usd: balance.amount_usd
      })
    end)

    # Guardar detalles de liability
    Enum.each(socket.assigns.liability_details, fn {account_id, detail} ->
      balance_data = socket.assigns.balances[account_id]

      {:ok, balance} =
        Finance.upsert_balance(%{
          snapshot_id: snapshot.id,
          account_id: account_id,
          amount_nominal: detail.total_debt,
          amount_usd: balance_data.amount_usd
        })

      Finance.upsert_liability_detail(balance.id, detail)
    end)

    # Calcular net worth
    balances = Finance.list_balances_for_snapshot(snapshot.id)

    net_worth =
      Enum.reduce(balances, Decimal.new(0), fn b, acc ->
        Decimal.add(acc, b.amount_usd)
      end)

    # Confirmar snapshot
    Finance.confirm_snapshot(snapshot, %{
      total_income_usd: socket.assigns.income.total_usd,
      total_net_worth_usd: net_worth,
      total_savings_usd: Decimal.new(0),
      total_yield_usd: Decimal.new(0),
      exchange_rate_blue: socket.assigns.dolar_blue
    })

    # Marcar onboarding como completado
    user = socket.assigns.current_scope.user
    Accounts.complete_onboarding(user)

    {:noreply,
     socket
     |> put_flash(:info, "¡Setup completado! Tu mapa financiero está listo.")
     |> push_navigate(to: ~p"/")}
  end

  # --- Internal Helpers ---

  defp maybe_auto_show_form(socket, step) when step in [3, 5] do
    type = current_step_type(step)
    accounts = socket.assigns.accounts
    
    if Enum.empty?(Enum.filter(accounts, & &1.type == type)) do
      form_data = %{"name" => nil, "currencies" => [], "original_name" => nil}
      socket
      |> assign(:show_form, true)
      |> assign(:form_type, type)
      |> assign(:form, to_form(form_data))
    else
      socket |> assign(:show_form, false)
    end
  end
  defp maybe_auto_show_form(socket, _step), do: assign(socket, :show_form, false)

  # --- Persistence Helpers ---

  defp persist_onboarding_data(socket) do
    user = socket.assigns.current_scope.user
    data = %{
      "balances" => serialize_balances(socket.assigns.balances),
      "liability_details" => serialize_liability_details(socket.assigns.liability_details),
      "preferences" => socket.assigns.preferences,
      "income" => serialize_income(socket.assigns.income)
    }
    Accounts.update_onboarding_data(user, data)
    socket
  end

  defp serialize_balances(balances) do
    Map.new(balances, fn {k, v} ->
      {k, %{"amount_nominal" => Decimal.to_string(v.amount_nominal), "amount_usd" => Decimal.to_string(v.amount_usd)}}
    end)
  end

  defp serialize_liability_details(details) do
    Map.new(details, fn {k, v} ->
      {k, %{
        "current_period_balance" => Decimal.to_string(v.current_period_balance),
        "future_installments_balance" => Decimal.to_string(v.future_installments_balance),
        "total_debt" => Decimal.to_string(Map.get(v, :total_debt, Decimal.new(0)))
      }}
    end)
  end

  defp serialize_income(income) do
    %{
      "ars" => Decimal.to_string(income.ars),
      "usd" => Decimal.to_string(income.usd),
      "total_usd" => Decimal.to_string(income.total_usd)
    }
  end

  defp restore_balances(nil), do: %{}
  defp restore_balances(data) when is_map(data) do
    Map.new(data, fn {k, v} ->
      {k, %{
        amount_nominal: Decimal.new(v["amount_nominal"] || "0"),
        amount_usd: Decimal.new(v["amount_usd"] || "0")
      }}
    end)
  end

  defp restore_liability_details(nil), do: %{}
  defp restore_liability_details(data) when is_map(data) do
    Map.new(data, fn {k, v} ->
      {k, %{
        current_period_balance: Decimal.new(v["current_period_balance"] || "0"),
        future_installments_balance: Decimal.new(v["future_installments_balance"] || "0"),
        total_debt: Decimal.new(v["total_debt"] || "0")
      }}
    end)
  end

  defp restore_preferences(nil), do: %{investments: false, debts: false}
  defp restore_preferences(data) when is_map(data) do
    %{
      investments: data["investments"] || false,
      debts: data["debts"] || false
    }
  end

  defp restore_income(nil), do: %{ars: Decimal.new(0), usd: Decimal.new(0), total_usd: Decimal.new(0)}
  defp restore_income(data) when is_map(data) do
    %{
      ars: Decimal.new(data["ars"] || "0"),
      usd: Decimal.new(data["usd"] || "0"),
      total_usd: Decimal.new(data["total_usd"] || "0")
    }
  end

  # parse_currency imported from NumberHelpers

  defp step_name(1), do: "Bienvenida"
  defp step_name(2), do: "Preferencias"
  defp step_name(3), do: "Cuentas"
  defp step_name(4), do: "Inversiones"
  defp step_name(5), do: "Deudas"
  defp step_name(6), do: "Saldos"
  defp step_name(7), do: "Ingresos"
  defp step_name(8), do: "Resumen"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto px-4 py-6">
      <!-- Progress Glass -->
      <div class="glass-card-static p-3 mb-8 animate-fade-in">
        <div class="flex items-center gap-2">
          <%= for i <- 1..8 do %>
            <div class={"h-1.5 flex-1 rounded-full transition-all duration-300 #{if i <= @step, do: "bg-gradient-to-r from-indigo-500 to-purple-500", else: "bg-gray-300/50"}"}></div>
          <% end %>
        </div>
        <div class="flex justify-between mt-2 text-xs opacity-50">
          <span>Paso <%= @step %> de 8</span>
          <span><%= step_name(@step) %></span>
        </div>
      </div>

      <%= case @step do %>
        <% 1 -> %>
          <.step_welcome />

        <% 2 -> %>
          <.step_selection preferences={@preferences} />

        <% 3 -> %>
          <.step_accounts
            accounts={@accounts}
            show_form={@show_form}
            form_type={@form_type}
            form={@form}
            title="Tus Cuentas Líquidas"
            description="Bancos, billeteras virtuales y efectivo."
            type={:liquid}
          />

        <% 4 -> %>
          <.step_investments
            accounts={@accounts}
            show_form={@show_form}
            form_type={@form_type}
            form={@form}
          />

        <% 5 -> %>
          <.step_accounts
            accounts={@accounts}
            show_form={@show_form}
            form_type={@form_type}
            form={@form}
            title="Tus Deudas"
            description="Tarjetas de crédito, préstamos."
            type={:liability}
          />

        <% 6 -> %>
          <.step_balances
            accounts={@accounts}
            balances={@balances}
            liability_details={@liability_details}
            dolar_blue={@dolar_blue}
          />

         <% 7 -> %>
          <.step_income
            income={@income}
          />

        <% 8 -> %>
          <.step_summary
            accounts={@accounts}
            balances={@balances}
            income={@income}
          />
      <% end %>

      <!-- Navigation Glass -->
      <div class="flex gap-3 mt-8">
        <%= if @step > 1 do %>
          <button phx-click="prev_step" class="btn btn-glass flex-1 touch-target">
            <span class="hero-arrow-left mr-2"></span>
            Anterior
          </button>
        <% else %>
          <div class="flex-1"></div>
        <% end %>

         <%= if @step == 8 do %>
          <button
            phx-click="complete_onboarding"
            class="fab-button-pill flex-1 h-14 touch-target"
            disabled={Enum.empty?(@accounts)}
          >
            <span class="hero-check mr-2"></span>
            Completar Setup
          </button>
        <% else %>
          <button
            phx-click="next_step"
            class="fab-button-pill flex-1 h-14 touch-target"
            disabled={@step >= 3 and @step <= 5 and Enum.empty?(Enum.filter(@accounts, & &1.type == current_step_type(@step))) and false}
          >
            <%= if @step == 1, do: "Comenzar", else: "Siguiente" %>
            <span class="hero-arrow-right ml-2"></span>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp step_welcome(assigns) do
    ~H"""
    <div class="text-center py-8 animate-scale-in">
      <div class="w-24 h-24 mx-auto mb-8 rounded-2xl bg-gradient-to-br from-indigo-500/20 to-purple-500/20 flex items-center justify-center">
        <span class="hero-map text-5xl text-indigo-600"></span>
      </div>
      <h1 class="text-4xl font-extrabold mb-4 text-gradient-hero">Bienvenido a PerFi Delta</h1>
      <p class="text-gray-600 mb-6 text-lg">
        Vamos a configurar todas tus cuentas, inversiones y deudas.
      </p>
      <div class="glass-card p-4 mx-auto max-w-sm">
        <p class="text-sm opacity-60">
          Este es tu punto de partida. A partir de acá, podrás medir tu progreso real cada mes.
        </p>
      </div>
    </div>
    """
  end

  defp step_accounts(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2"><%= @title %></h2>
      <p class="text-base-content/60 mb-6">
        <%= @description %>
      </p>

      <!-- Botón para agregar -->
      <div class="mb-6">
        <button
          phx-click="show_form"
          phx-value-type={@type}
          class={"btn btn-outline btn-lg w-full flex items-center gap-3 #{account_btn_class(@type)}"}
        >
          <span class={account_icon(@type)}></span>
          <span>Agregar <%= account_type_label(@type) %></span>
        </button>
      </div>

      <!-- Modal Form -->
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black/50 z-50 flex items-end sm:items-center justify-center p-4">
          <div class="card-zen w-full max-w-md p-6 animate-fade-in">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-bold">Nueva Cuenta</h3>
              <button phx-click="hide_form" class="btn btn-ghost btn-circle btn-sm">
                <span class="hero-x-mark"></span>
              </button>
            </div>

            <.form for={@form} phx-change="validate" phx-submit="save_account" class="space-y-4">
              <input type="hidden" name="dummy" value="fix_phoenix_bug" />
              <input type="hidden" name="original_name" value={@form[:original_name].value} />

              <div class="form-control">
                <label class="label"><span class="label-text">Nombre</span></label>
                <input
                  type="text"
                  name="name"
                  id="account-name-input"
                  phx-hook="Focus"
                  value={@form[:name].value}
                  placeholder={placeholder_for_type(@form_type)}
                  class="input input-bordered w-full"
                  required
                />
              </div>

              <div class="form-control">
                <label class="label"><span class="label-text">Moneda</span></label>
                <div class="grid grid-cols-2 gap-2">
                  <%= for {label, value} <- currencies_for_type(@form_type) do %>
                    <label class="label cursor-pointer justify-start gap-3 border rounded-lg p-2 hover:bg-base-200">
                      <input 
                        type="checkbox" 
                        name="currencies[]" 
                        value={value} 
                        class="checkbox checkbox-primary checkbox-sm"
                        checked={value in (@form[:currencies].value || [])}
                      />
                      <span class="label-text"><%= label %></span>
                    </label>
                  <% end %>
                </div>
              </div>

              <div class="flex gap-3 pt-4">
                <button type="button" phx-click="hide_form" class="btn btn-ghost flex-1">
                  Cancelar
                </button>
                <button type="submit" class="btn btn-primary flex-1">
                  Guardar
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <!-- Lista de cuentas agregadas para este paso (Grouped) -->
      <% current_accounts = Enum.filter(@accounts, & &1.type == @type) %>
      <% grouped_accounts = Enum.group_by(current_accounts, & &1.name) %>
      
      <%= if map_size(grouped_accounts) > 0 do %>
        <div class="space-y-2">
          <%= for {name, group} <- grouped_accounts do %>
            <% first = hd(group) %>
            <div class="card-zen p-3 flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div class={"w-10 h-10 rounded-full flex items-center justify-center #{account_bg_class(first.type)}"}>
                  <span class={"text-lg #{account_icon(first.type)}"}></span>
                </div>
                <div>
                  <p class="font-medium"><%= name %></p>
                  <div class="flex gap-1 mt-1">
                    <%= for acc <- group do %>
                      <span class="badge badge-xs badge-ghost"><%= acc.currency %></span>
                    <% end %>
                  </div>
                </div>
              </div>
              <div class="flex items-center gap-2">
                 <button 
                    phx-click="edit_account" 
                    phx-value-name={name}
                    phx-value-type={first.type}
                    class="btn btn-ghost btn-circle btn-sm"
                 >
                   <span class="hero-pencil"></span>
                 </button>
                 <button 
                    phx-click="delete_group" 
                    phx-value-name={name}
                    phx-value-type={first.type}
                    class="btn btn-ghost btn-circle btn-sm text-error"
                 >
                   <span class="hero-trash"></span>
                 </button>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="text-center py-8 text-base-content/40">
          <p>No agregaste ninguna cuenta todavía.</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp step_balances(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2">Saldos Actuales</h2>
      <p class="text-base-content/60 mb-2">Ingresá los saldos de hoy para empezar.</p>
      <%= if @dolar_blue do %>
        <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-base-200 text-xs text-base-content/50 mb-6">
          <span class="hero-currency-dollar size-3"></span>
          <span>Dólar Blue: <strong>$<%= Decimal.round(@dolar_blue, 0) %></strong></span>
        </div>
      <% end %>

      <div class="space-y-6">
        <!-- Activos (Líquidos e Inversiones) -->
        <% assets = Enum.filter(@accounts, & &1.type in [:liquid, :investment]) %>
        <% grouped_assets = Enum.group_by(assets, & &1.name) %>
        
        <%= for {name, group} <- grouped_assets do %>
          <% first = hd(group) %>
          <div class={["p-5 transition-all duration-300", account_card_class(first.type)]}>
            <div class="flex items-center justify-between mb-5">
              <div class="flex items-center gap-3">
                <div class={["w-10 h-10 rounded-xl flex items-center justify-center shadow-sm", account_bg_class(first.type)]}>
                  <span class={["text-xl", account_icon(first.type)]}></span>
                </div>
                <div>
                  <p class="font-bold text-lg leading-none mb-1"><%= name %></p>
                  <p class="text-xs uppercase tracking-widest font-semibold #{account_text_class(first.type)}"><%= account_type_label(first.type) %></p>
                </div>
              </div>
            </div>
            
            <div class="space-y-4">
              <%= for account <- group do %>
                  <div class="relative group">
                      <input
                        type="tel"
                        inputmode="decimal"
                        placeholder="0"
                        value={get_balance(@balances, account.id)}
                        phx-blur="update_balance"
                        phx-value-account_id={account.id}
                        phx-hook="NumberFormat"
                        id={"balance-#{account.id}"}
                        class="input input-lg w-full bg-base-100/50 border-base-content/10 focus:border-primary/30 text-right font-mono-numbers text-2xl pr-20"
                      />
                    <span class="absolute right-4 top-1/2 -translate-y-1/2 text-base-content/30 font-bold text-sm pointer-events-none">
                      <%= account.currency %>
                    </span>
                    <!-- USD Conversion Indicator -->
                    <%= if account.currency != "USD" and Map.has_key?(@balances, account.id) do %>
                      <div class="text-right mt-1 pr-2 text-xs opacity-40 font-mono-numbers">
                        ≈ US$ <%= @balances[account.id].amount_usd %>
                      </div>
                    <% end %>
                  </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Pasivos (Deudas) -->
        <% liabilities = Enum.filter(@accounts, & &1.type == :liability) %>
        <% grouped_liabilities = Enum.group_by(liabilities, & &1.name) %>
        
        <%= for {name, group} <- grouped_liabilities do %>
          <% first = hd(group) %>
          <div class={["p-5 transition-all duration-300", account_card_class(first.type)]}>
            <div class="flex items-center gap-3 mb-5">
              <div class={["w-10 h-10 rounded-xl flex items-center justify-center shadow-sm", account_bg_class(first.type)]}>
                <span class={["text-xl", account_icon(first.type)]}></span>
              </div>
              <div>
                <p class="font-bold text-lg leading-none mb-1"><%= name %></p>
                <p class="text-xs uppercase tracking-widest font-semibold #{account_text_class(first.type)}"><%= account_type_label(first.type) %></p>
              </div>
            </div>

            <div class="space-y-8">
              <%= for account <- group do %>
                <div class="space-y-4 pt-4 border-t #{account_border_class(first.type)} first:pt-0 first:border-0">
                  <div class="flex items-center gap-2">
                    <div class="h-px flex-1 #{account_border_class(first.type)}"></div>
                  </div>
                  
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div class="space-y-1.5">
                      <label class="text-[10px] uppercase tracking-wider font-bold opacity-40 ml-1">Consumo Actual</label>
                      <div class="relative">
                        <input
                          type="tel"
                          inputmode="decimal"
                          placeholder="0"
                          value={get_liability_field(@liability_details, account.id, :current_period_balance)}
                          phx-blur="update_liability"
                          phx-value-account_id={account.id}
                          phx-value-field="current"
                          phx-hook="NumberFormat"
                          id={"liability-current-#{account.id}"}
                          class="input input-bordered w-full bg-base-100/50 text-right font-mono-numbers text-xl pr-16"
                        />
                        <span class="absolute right-4 top-1/2 -translate-y-1/2 text-base-content/30 font-bold text-xs pointer-events-none uppercase">
                          <%= account.currency %>
                        </span>
                      </div>
                    </div>
                    <div class="space-y-1.5">
                      <label class="text-[10px] uppercase tracking-wider font-bold opacity-40 ml-1">Cuotas Futuras</label>
                      <div class="relative">
                        <input
                          type="tel"
                          inputmode="decimal"
                          placeholder="0"
                          value={get_liability_field(@liability_details, account.id, :future_installments_balance)}
                          phx-blur="update_liability"
                          phx-value-account_id={account.id}
                          phx-value-field="future"
                          phx-hook="NumberFormat"
                          id={"liability-future-#{account.id}"}
                          class="input input-bordered w-full bg-base-100/50 text-right font-mono-numbers text-xl pr-16"
                        />
                        <span class="absolute right-4 top-1/2 -translate-y-1/2 text-base-content/30 font-bold text-xs pointer-events-none uppercase">
                          <%= account.currency %>
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp step_summary(assigns) do
    ~H"""
    <div class="text-center">
      <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-success/10 flex items-center justify-center">
        <span class="hero-check-circle text-3xl text-success"></span>
      </div>
      <h2 class="text-2xl font-bold mb-2">Todo Listo</h2>
      <p class="text-base-content/60 mb-8">
        Este será tu punto de partida.
      </p>

      <div class="score-card mb-6">
        <p class="text-xs text-base-content/40 mb-1">Tu Punto de Partida</p>
        <div class="flex flex-col gap-1 items-center mb-4">
          <p class="text-sm text-base-content/60">Patrimonio Neto Inicial</p>
          <p class="text-4xl font-mono-numbers font-bold">
            US$ <%= calculate_net_worth(@balances) %>
          </p>
        </div>
        
        <div class="pt-4 border-t border-base-content/10 flex justify-between items-center bg-base-200/30 -mx-6 px-6 py-3 rounded-b-xl">
          <span class="text-sm text-base-content/60">Ingreso Mensual</span>
          <span class="text-lg font-mono-numbers font-bold text-primary">
            US$ <%= format_currency(@income.total_usd) %>
          </span>
        </div>
      </div>

      <div class="grid grid-cols-3 gap-3 mb-6">
        <div class="card-gradient-liquid p-4 text-center">
          <p class="text-lg font-mono-numbers font-bold"><%= format_compact_usd(sum_by_type(@balances, @accounts, :liquid)) %></p>
          <p class="text-xs text-base-content/60">Líquidas</p>
        </div>
        <div class="card-gradient-investment p-4 text-center">
          <p class="text-lg font-mono-numbers font-bold"><%= format_compact_usd(sum_by_type(@balances, @accounts, :investment)) %></p>
          <p class="text-xs text-base-content/60">Inversiones</p>
        </div>
        <div class="card-gradient-liability p-4 text-center">
          <p class="text-lg font-mono-numbers font-bold text-error"><%= format_compact_usd(sum_by_type(@balances, @accounts, :liability)) %></p>
          <p class="text-xs text-base-content/60">Deudas</p>
        </div>
      </div>

      <p class="text-sm text-base-content/50">
        A partir de ahora, cada mes podrás hacer un "cierre" para ver cuánto ahorraste realmente y cuánto rindieron tus inversiones.
      </p>
    </div>
    """
  end

  defp step_income(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2">Ingresos Mensuales</h2>
      <p class="text-base-content/60 mb-8">
        Para calcular cuánto podés ahorrar, necesitamos saber cuáles son tus ingresos promedio por mes.
      </p>

      <div class="space-y-6">
        <div class="card-zen p-5 border-primary/20 bg-primary/5">
          <div class="space-y-4">
            <div class="space-y-1.5">
              <label class="text-[10px] uppercase tracking-wider font-bold opacity-40 ml-1">Ingresos en ARS</label>
              <div class="relative">
                <input
                  type="tel"
                  inputmode="decimal"
                  placeholder="0"
                  value={Decimal.to_string(@income.ars) |> String.replace(".", ",")}
                  phx-blur="update_income"
                  phx-value-currency="ARS"
                  phx-hook="NumberFormat"
                  id="income-ars"
                  class="input input-lg w-full bg-base-100/50 border-base-content/10 focus:border-primary/30 text-right font-mono-numbers text-2xl pr-20"
                />
                <span class="absolute right-4 top-1/2 -translate-y-1/2 text-base-content/30 font-bold text-sm pointer-events-none">
                  ARS
                </span>
              </div>
            </div>

            <div class="space-y-1.5">
              <label class="text-[10px] uppercase tracking-wider font-bold opacity-40 ml-1">Ingresos en USD</label>
              <div class="relative">
                <input
                  type="tel"
                  inputmode="decimal"
                  placeholder="0"
                  value={Decimal.to_string(@income.usd) |> String.replace(".", ",")}
                  phx-blur="update_income"
                  phx-value-currency="USD"
                  phx-hook="NumberFormat"
                  id="income-usd"
                  class="input input-lg w-full bg-base-100/50 border-base-content/10 focus:border-primary/30 text-right font-mono-numbers text-2xl pr-20"
                />
                <span class="absolute right-4 top-1/2 -translate-y-1/2 text-base-content/30 font-bold text-sm pointer-events-none">
                  USD
                </span>
              </div>
            </div>
            
            <div class="pt-4 border-t border-base-content/10">
              <div class="flex justify-between items-center">
                <span class="text-sm font-medium opacity-60">Total Mensual</span>
                <span class="text-xl font-mono-numbers font-bold text-primary">
                  US$ <%= format_currency(@income.total_usd) %>
                </span>
              </div>
            </div>
          </div>
        </div>

        <div class="p-4 bg-base-200/50 rounded-xl flex gap-3 items-start">
          <span class="hero-information-circle text-primary mt-0.5"></span>
          <p class="text-xs text-base-content/60 leading-relaxed">
            No te preocupes si no es exacto, podés ajustarlo después. Este valor nos sirve para ver si estás logrando tus metas de ahorro.
          </p>
        </div>
      </div>
    </div>
    """
  end



  defp step_selection(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2">Personalizá tu experiencia</h2>
      <p class="text-base-content/60 mb-8">
        Seleccioná qué tipos de cuentas querés agregar ahora.
      </p>

      <div class="space-y-4">
        <button
          phx-click="toggle_preference"
          phx-value-type="investments"
          class={"w-full p-4 rounded-xl border-2 transition-all flex items-center justify-between group #{
            if @preferences.investments, do: "border-primary bg-primary/5", else: "border-base-200 hover:border-primary/50"
          }"}
        >
          <div class="flex items-center gap-4">
            <div class={"w-12 h-12 rounded-full flex items-center justify-center transition-colors #{
              if @preferences.investments, do: "bg-primary text-primary-content", else: "bg-base-200 text-base-content/50"
            }"}>
              <span class="hero-chart-bar text-xl"></span>
            </div>
            <div class="text-left">
              <p class={"font-bold transition-colors #{if @preferences.investments, do: "text-primary"}"}>
                Tengo Inversiones
              </p>
              <p class="text-sm text-base-content/60">
                Acciones, Bonos, Criptomonedas, FCI
              </p>
            </div>
          </div>
          <div class={"w-6 h-6 rounded-full border-2 flex items-center justify-center transition-all #{
            if @preferences.investments, do: "border-primary bg-primary", else: "border-base-300"
          }"}>
            <span class="hero-check text-white text-xs"></span>
          </div>
        </button>

        <button
          phx-click="toggle_preference"
          phx-value-type="debts"
          class={"w-full p-4 rounded-xl border-2 transition-all flex items-center justify-between group #{
            if @preferences.debts, do: "border-primary bg-primary/5", else: "border-base-200 hover:border-primary/50"
          }"}
        >
          <div class="flex items-center gap-4">
            <div class={"w-12 h-12 rounded-full flex items-center justify-center transition-colors #{
              if @preferences.debts, do: "bg-primary text-primary-content", else: "bg-base-200 text-base-content/50"
            }"}>
              <span class="hero-credit-card text-xl"></span>
            </div>
            <div class="text-left">
              <p class={"font-bold transition-colors #{if @preferences.debts, do: "text-primary"}"}>
                Tengo Deudas
              </p>
              <p class="text-sm text-base-content/60">
                Tarjetas de crédito, Préstamos
              </p>
            </div>
          </div>
          <div class={"w-6 h-6 rounded-full border-2 flex items-center justify-center transition-all #{
            if @preferences.debts, do: "border-primary bg-primary", else: "border-base-300"
          }"}>
            <span class="hero-check text-white text-xs"></span>
          </div>
        </button>
      </div>
    </div>
    """
  end

  defp step_investments(assigns) do
    presets = [
      %{name: "Bitcoin", currency: "BTC", icon: "hero-currency-dollar"},
      %{name: "Ethereum", currency: "ETH", icon: "hero-currency-dollar"},
      %{name: "USDT", currency: "USDT", icon: "hero-currency-dollar"},
      %{name: "S&P 500", currency: "USD", icon: "hero-chart-bar"},
      %{name: "FCI Money Market", currency: "ARS", icon: "hero-banknotes"}
    ]
    
    assigns = assign(assigns, :presets, presets)
    
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2">Tus Inversiones</h2>
      <p class="text-base-content/60 mb-6">
        Seleccioná las inversiones que tenés actualmente.
      </p>

      <div class="space-y-3 mb-8">
        <%= for preset <- @presets do %>
          <% 
             is_selected = Enum.any?(@accounts, fn a -> 
               a.type == :investment and a.name == preset.name and a.currency == preset.currency 
             end)
          %>
          <button
            phx-click="toggle_investment_preset"
            phx-value-name={preset.name}
            phx-value-currency={preset.currency}
            class={"w-full p-3 rounded-lg border-2 transition-all flex items-center justify-between group #{
              if is_selected, do: "border-primary bg-primary/5", else: "border-base-200 hover:border-primary/50"
            }"}
          >
            <div class="flex items-center gap-3">
              <div class={"w-10 h-10 rounded-full flex items-center justify-center transition-colors #{
                if is_selected, do: "bg-primary text-primary-content", else: "bg-base-200 text-base-content/50"
              }"}>
                <span class={preset.icon}></span>
              </div>
              <div class="text-left">
                <p class={"font-medium #{if is_selected, do: "text-primary"}"}><%= preset.name %></p>
                <p class="text-xs text-base-content/50"><%= preset.currency %></p>
              </div>
            </div>
            
            <div class={"w-6 h-6 rounded-full border-2 flex items-center justify-center transition-all #{
              if is_selected, do: "border-primary bg-primary", else: "border-base-300"
            }"}>
              <span class="hero-check text-white text-xs"></span>
            </div>
          </button>
        <% end %>
      </div>

      <div class="divider text-xs text-base-content/40">O agregá otra</div>

      <!-- Botón para agregar custom -->
      <div class="mb-6">
        <button
          phx-click="show_form"
          phx-value-type="investment"
          class="btn btn-outline btn-block"
        >
          <span class="hero-plus"></span>
          <span>Agregar Otra Inversión</span>
        </button>
      </div>

      <!-- Modal Form (Standard) -->
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black/50 z-50 flex items-end sm:items-center justify-center p-4">
          <div class="card-zen w-full max-w-md p-6 animate-fade-in">
             <!-- Same form logic as generic step -->
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-bold">Nueva Inversión</h3>
              <button phx-click="hide_form" class="btn btn-ghost btn-circle btn-sm">
                <span class="hero-x-mark"></span>
              </button>
            </div>

            <.form for={@form} phx-change="validate" phx-submit="save_account" class="space-y-4">
              <input type="hidden" name="dummy" value="fix_phoenix_bug" />
              <input type="hidden" name="original_name" value={@form[:original_name].value} />

              <div class="form-control">
                <label class="label"><span class="label-text">Nombre</span></label>
                <input
                  type="text"
                  name="name"
                  id="investment-name-input"
                  phx-hook="Focus"
                  value={@form[:name].value}
                  placeholder="Ej: Bonos AL30, Apple"
                  class="input input-bordered w-full"
                  required
                />
              </div>

              <div class="form-control">
                <label class="label"><span class="label-text">Moneda</span></label>
                <div class="grid grid-cols-2 gap-2">
                  <%= for {label, value} <- currencies_for_type(:investment) do %>
                    <label class="label cursor-pointer justify-start gap-3 border rounded-lg p-2 hover:bg-base-200">
                      <input 
                        type="checkbox" 
                        name="currencies[]" 
                        value={value} 
                        class="checkbox checkbox-primary checkbox-sm"
                        checked={value in (@form[:currencies].value || [])}
                      />
                      <span class="label-text"><%= label %></span>
                    </label>
                  <% end %>
                </div>
              </div>

              <div class="flex gap-3 pt-4">
                <button type="button" phx-click="hide_form" class="btn btn-ghost flex-1">
                  Cancelar
                </button>
                <button type="submit" class="btn btn-primary flex-1">
                  Guardar
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <!-- Custom added accounts list (Only those NOT in presets) -->
      <% 
         preset_keys = Enum.map(@presets, & {&1.name, &1.currency})
         custom_accounts = Enum.filter(@accounts, fn a -> 
           a.type == :investment and {a.name, a.currency} not in preset_keys 
         end)
         grouped_custom = Enum.group_by(custom_accounts, & &1.name)
      %>
      
      <%= if map_size(grouped_custom) > 0 do %>
        <div class="space-y-2 mt-4">
          <h3 class="font-bold text-sm text-base-content/50 uppercase">Otras Inversiones</h3>
          <%= for {name, group} <- grouped_custom do %>
            <% first = hd(group) %>
            <div class="card-zen p-3 flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div class={"w-10 h-10 rounded-full flex items-center justify-center #{account_bg_class(first.type)}"}>
                  <span class={"text-lg #{account_icon(first.type)}"}></span>
                </div>
                <div>
                  <p class="font-medium"><%= name %></p>
                  <div class="flex gap-1 mt-1">
                    <%= for acc <- group do %>
                      <span class="badge badge-xs badge-ghost"><%= acc.currency %></span>
                    <% end %>
                  </div>
                </div>
              </div>
              <div class="flex items-center gap-2">
                 <button 
                    phx-click="edit_account" 
                    phx-value-name={name}
                    phx-value-type={first.type}
                    class="btn btn-ghost btn-circle btn-sm"
                 >
                   <span class="hero-pencil"></span>
                 </button>
                 <button 
                    phx-click="delete_group" 
                    phx-value-name={name}
                    phx-value-type={first.type}
                    class="btn btn-ghost btn-circle btn-sm text-error"
                 >
                   <span class="hero-trash"></span>
                 </button>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

    </div>
    """
  end

  # Helpers
  
  # format_currency delegated to NumberHelpers via import

  defp placeholder_for_type(:liquid), do: "Ej: Banco Galicia, Efectivo"
  defp placeholder_for_type(:investment), do: "Ej: Binance BTC, FCI, Acciones"
  defp placeholder_for_type(:liability), do: "Ej: Visa, Préstamo"

  defp currencies_for_type(:liquid) do
    [{"ARS - Peso Argentino", "ARS"}, {"USD - Dólar", "USD"}]
  end

  defp currencies_for_type(:investment) do
    [
      {"USD - Dólar", "USD"},
      {"USDT - Tether", "USDT"},
      {"BTC - Bitcoin", "BTC"},
      {"ETH - Ethereum", "ETH"},
      {"ARS - Peso Argentino", "ARS"}
    ]
  end

  defp currencies_for_type(:liability) do
    [{"ARS - Peso Argentino", "ARS"}, {"USD - Dólar", "USD"}]
  end

  defp get_balance(balances, account_id) do
    case Map.get(balances, account_id) do
      %{amount_nominal: amount} -> amount |> Decimal.to_string() |> String.replace(".", ",")
      _ -> ""
    end
  end

  defp get_liability_field(details, account_id, field) do
    case Map.get(details, account_id) do
      nil -> ""
      detail -> 
        val = Map.get(detail, field)
        if val, do: val |> Decimal.to_string() |> String.replace(".", ","), else: ""
    end
  end

  defp calculate_net_worth(balances) do
    balances
    |> Map.values()
    |> Enum.reduce(Decimal.new(0), fn %{amount_usd: usd}, acc ->
      Decimal.add(acc, usd)
    end)
    |> Decimal.round(0)
    |> Decimal.to_string()
    |> add_thousands_separator()
  end

  # add_thousands_separator/1 delegated to NumberHelpers via import

  defp sum_by_type(balances, accounts, type) do
    accounts
    |> Enum.filter(&(&1.type == type))
    |> Enum.reduce(Decimal.new(0), fn account, acc ->
      case Map.get(balances, account.id) do
        %{amount_usd: amount_usd} -> Decimal.add(acc, amount_usd)
        _ -> acc
      end
    end)
  end

  defp format_compact_usd(decimal_usd) do
    abs_value = Decimal.abs(decimal_usd)
    is_negative = Decimal.negative?(decimal_usd)
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


  defp account_card_class(:liquid), do: "card-gradient-liquid shadow-sm border-success/10"
  defp account_card_class(:investment), do: "card-gradient-investment shadow-sm border-accent/10"
  defp account_card_class(:liability), do: "card-gradient-liability shadow-sm border-error/10"
  defp account_card_class(_), do: "card-zen border-base-300"

  defp account_bg_class(:liquid), do: "bg-primary/10 text-primary"
  defp account_bg_class(:investment), do: "bg-accent/10 text-accent"
  defp account_bg_class(:liability), do: "bg-error/10 text-error"
  defp account_bg_class(_), do: "bg-base-200 text-base-content"

  defp account_icon(:liquid), do: "hero-banknotes"
  defp account_icon(:investment), do: "hero-chart-bar"
  defp account_icon(:liability), do: "hero-credit-card"
  defp account_icon(_), do: "hero-question-mark-circle"

  defp account_type_label(:liquid), do: "Líquida"
  defp account_type_label(:investment), do: "Inversión"
  defp account_type_label(:liability), do: "Deuda"

  defp current_step_type(3), do: :liquid
  defp current_step_type(4), do: :investment
  defp current_step_type(5), do: :liability
  defp current_step_type(_), do: nil

  defp account_btn_class(:liquid), do: "btn-primary"
  defp account_btn_class(:investment), do: "btn-accent"
  defp account_btn_class(:liability), do: "btn-error"
end
