defmodule PerfiDelta.Finance do
  @moduledoc """
  Contexto de Finanzas - maneja cuentas, snapshots, y el motor de cálculo.
  """

  import Ecto.Query, warn: false
  alias PerfiDelta.Repo

  alias PerfiDelta.Finance.{
    FinancialAccount,
    Snapshot,
    AccountBalance,
    LiabilityDetail,
    InvestmentFlow,
    ExchangeRate
  }

  # ==============================================================================
  # Financial Accounts
  # ==============================================================================

  @doc "Lista todas las cuentas activas de un usuario"
  def list_accounts(user_id) do
    FinancialAccount
    |> where([a], a.user_id == ^user_id and is_nil(a.deleted_at))
    |> order_by([a], [a.type, a.name])
    |> Repo.all()
  end

  @doc "Lista cuentas con sus últimos balances del snapshot más reciente"
  def list_accounts_with_latest_balances(user_id) do
    accounts = list_accounts(user_id)

    case get_latest_confirmed_snapshot(user_id) do
      nil ->
        # Sin snapshot, retornar cuentas con balance nil
        Enum.map(accounts, fn account ->
          Map.put(account, :latest_balance, nil)
        end)

      snapshot ->
        balances = list_balances_for_snapshot(snapshot.id)
        balance_map = Map.new(balances, fn b -> {b.account_id, b} end)

        Enum.map(accounts, fn account ->
          balance = Map.get(balance_map, account.id)
          Map.put(account, :latest_balance, balance)
        end)
    end
  end

  @doc "Lista cuentas por tipo"
  def list_accounts_by_type(user_id, type) when type in [:liquid, :investment, :liability] do
    FinancialAccount
    |> where([a], a.user_id == ^user_id and a.type == ^type and is_nil(a.deleted_at))
    |> order_by([a], a.name)
    |> Repo.all()
  end

  @doc "Obtiene una cuenta por ID"
  def get_account!(id), do: Repo.get!(FinancialAccount, id)

  def get_account(id), do: Repo.get(FinancialAccount, id)

  @doc "Crea una nueva cuenta financiera"
  def create_account(attrs \\ %{}) do
    %FinancialAccount{}
    |> FinancialAccount.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Actualiza una cuenta existente"
  def update_account(%FinancialAccount{} = account, attrs) do
    account
    |> FinancialAccount.changeset(attrs)
    |> Repo.update()
  end

  @doc "Soft delete de una cuenta"
  def delete_account(%FinancialAccount{} = account) do
    account
    |> FinancialAccount.soft_delete_changeset()
    |> Repo.update()
  end

  def change_account(%FinancialAccount{} = account, attrs \\ %{}) do
    FinancialAccount.changeset(account, attrs)
  end

  # ==============================================================================
  # Snapshots
  # ==============================================================================

  @doc "Obtiene el snapshot más reciente confirmado de un usuario"
  def get_latest_confirmed_snapshot(user_id) do
    Snapshot
    |> where([s], s.user_id == ^user_id and s.status == :confirmed and is_nil(s.deleted_at))
    |> order_by([s], desc: s.year, desc: s.month)
    |> limit(1)
    |> Repo.one()
  end

  @doc "Obtiene o crea un snapshot draft para el mes actual"
  def get_or_create_current_snapshot(user_id) do
    now = DateTime.now!("America/Argentina/Buenos_Aires")
    month = now.month
    year = now.year

    case get_snapshot_by_period(user_id, month, year) do
      nil -> create_snapshot(%{user_id: user_id, month: month, year: year})
      snapshot -> {:ok, snapshot}
    end
  end

  @doc "Obtiene snapshot por periodo"
  def get_snapshot_by_period(user_id, month, year) do
    Snapshot
    |> where([s], s.user_id == ^user_id and s.month == ^month and s.year == ^year)
    |> where([s], is_nil(s.deleted_at))
    |> Repo.one()
  end

  @doc "Obtiene un snapshot con sus relaciones"
  def get_snapshot_with_details!(id) do
    Snapshot
    |> where([s], s.id == ^id)
    |> preload([
      :investment_flows,
      account_balances: [:account, :liability_detail]
    ])
    |> Repo.one!()
  end

  @doc "Lista los snapshots confirmados de un usuario"
  def list_confirmed_snapshots(user_id) do
    Snapshot
    |> where([s], s.user_id == ^user_id and s.status == :confirmed and is_nil(s.deleted_at))
    |> order_by([s], desc: s.year, desc: s.month)
    |> Repo.all()
  end

  @doc "Crea un nuevo snapshot"
  def create_snapshot(attrs \\ %{}) do
    %Snapshot{}
    |> Snapshot.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Confirma un snapshot con los cálculos finales"
  def confirm_snapshot(%Snapshot{} = snapshot, attrs) do
    snapshot
    |> Snapshot.confirm_changeset(attrs)
    |> Repo.update()
  end

  def change_snapshot(%Snapshot{} = snapshot, attrs \\ %{}) do
    Snapshot.changeset(snapshot, attrs)
  end

  # ==============================================================================
  # Account Balances
  # ==============================================================================

  @doc "Lista los balances de un snapshot"
  def list_balances_for_snapshot(snapshot_id) do
    AccountBalance
    |> where([b], b.snapshot_id == ^snapshot_id and is_nil(b.deleted_at))
    |> preload([:account, :liability_detail])
    |> Repo.all()
  end

  @doc "Lista el historial de balances de una cuenta (todos los snapshots)"
  def list_balance_history(account_id) do
    AccountBalance
    |> where([b], b.account_id == ^account_id and is_nil(b.deleted_at))
    |> join(:inner, [b], s in Snapshot, on: b.snapshot_id == s.id)
    |> where([b, s], s.status == :confirmed)
    |> order_by([b, s], desc: s.year, desc: s.month)
    |> select([b, s], %{
      id: b.id,
      amount: b.amount_nominal,
      amount_usd: b.amount_usd,
      month: s.month,
      year: s.year,
      snapshot_id: s.id
    })
    |> Repo.all()
  end

  @doc "Crea o actualiza el balance de una cuenta en un snapshot"
  def upsert_balance(attrs) do
    case get_balance(attrs[:snapshot_id], attrs[:account_id]) do
      nil ->
        %AccountBalance{}
        |> AccountBalance.changeset(attrs)
        |> Repo.insert()

      balance ->
        balance
        |> AccountBalance.changeset(attrs)
        |> Repo.update()
    end
  end

  defp get_balance(snapshot_id, account_id) do
    AccountBalance
    |> where([b], b.snapshot_id == ^snapshot_id and b.account_id == ^account_id)
    |> Repo.one()
  end

  # ==============================================================================
  # Liability Details
  # ==============================================================================

  @doc "Crea o actualiza los detalles de deuda de un balance"
  def upsert_liability_detail(account_balance_id, attrs) do
    case get_liability_detail(account_balance_id) do
      nil ->
        attrs_with_id = Map.put(attrs, :account_balance_id, account_balance_id)

        %LiabilityDetail{}
        |> LiabilityDetail.changeset(attrs_with_id)
        |> Repo.insert()

      detail ->
        detail
        |> LiabilityDetail.changeset(attrs)
        |> Repo.update()
    end
  end

  defp get_liability_detail(account_balance_id) do
    LiabilityDetail
    |> where([d], d.account_balance_id == ^account_balance_id)
    |> Repo.one()
  end

  # ==============================================================================
  # Investment Flows
  # ==============================================================================

  @doc "Lista los flujos de inversión de un snapshot"
  def list_flows_for_snapshot(snapshot_id) do
    InvestmentFlow
    |> where([f], f.snapshot_id == ^snapshot_id and is_nil(f.deleted_at))
    |> Repo.all()
  end

  @doc "Crea un flujo de inversión"
  def create_investment_flow(attrs \\ %{}) do
    %InvestmentFlow{}
    |> InvestmentFlow.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Calcula el net flow total de un snapshot (deposits - withdrawals)"
  def calculate_net_flows(snapshot_id) do
    flows = list_flows_for_snapshot(snapshot_id)

    Enum.reduce(flows, Decimal.new(0), fn flow, acc ->
      Decimal.add(acc, InvestmentFlow.signed_amount(flow))
    end)
  end

  # ==============================================================================
  # Exchange Rates
  # ==============================================================================

  @doc "Obtiene la cotización más reciente de un par"
  def get_latest_rate(currency_pair, source \\ nil) do
    query =
      ExchangeRate
      |> where([r], r.currency_pair == ^currency_pair)
      |> order_by([r], desc: r.fetched_at)
      |> limit(1)

    query =
      if source do
        where(query, [r], r.source == ^source)
      else
        query
      end

    Repo.one(query)
  end

  @doc "Guarda una nueva cotización"
  def save_exchange_rate(attrs) do
    %ExchangeRate{}
    |> ExchangeRate.changeset(attrs)
    |> Repo.insert()
  end

  # ==============================================================================
  # Motor de Cálculo (Snapshot Engine)
  # ==============================================================================

  @doc """
  Calcula los valores del snapshot según las ecuaciones del PRD:

  1. Net Worth = Σ Activos - Σ Pasivos
  2. Delta NW = NW_actual - NW_anterior
  3. Yield = NW_actual - (NW_anterior + NetFlows)
  4. Savings = Delta NW - Yield = NetFlows (si no hay cambio de precios)
  5. Expenses = Income - Savings
  """
  def calculate_snapshot_values(snapshot_id, income_usd) do
    snapshot = get_snapshot_with_details!(snapshot_id)
    balances = list_balances_for_snapshot(snapshot_id)

    # Calcular Net Worth actual
    net_worth = calculate_net_worth(balances)

    # Obtener Net Worth anterior
    previous_snapshot = get_previous_snapshot(snapshot)
    previous_nw = if previous_snapshot, do: previous_snapshot.total_net_worth_usd, else: Decimal.new(0)

    # Calcular Net Flows
    net_flows = calculate_net_flows(snapshot_id)

    # Yield = NW_actual - (NW_anterior + NetFlows)
    expected_nw = Decimal.add(previous_nw, net_flows)
    yield = Decimal.sub(net_worth, expected_nw)

    # Savings = Delta NW - Yield
    delta_nw = Decimal.sub(net_worth, previous_nw)
    savings = Decimal.sub(delta_nw, yield)

    %{
      total_net_worth_usd: net_worth,
      total_income_usd: income_usd,
      total_savings_usd: savings,
      total_yield_usd: yield,
      delta_nw: delta_nw,
      expenses: Decimal.sub(income_usd, savings)
    }
  end

  defp calculate_net_worth(balances) do
    Enum.reduce(balances, Decimal.new(0), fn balance, acc ->
      Decimal.add(acc, balance.amount_usd)
    end)
  end

  defp get_previous_snapshot(%Snapshot{user_id: user_id, month: month, year: year}) do
    {prev_month, prev_year} =
      if month == 1, do: {12, year - 1}, else: {month - 1, year}

    get_snapshot_by_period(user_id, prev_month, prev_year)
  end
end
