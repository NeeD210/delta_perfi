defmodule PerfiDelta.Finance.Snapshot do
  @moduledoc """
  La foto mensual inmutable del estado financiero del usuario.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses [:draft, :confirmed]

  schema "snapshots" do
    field :month, :integer
    field :year, :integer
    field :status, Ecto.Enum, values: @statuses, default: :draft

    # Campos calculados/ingresados
    field :total_income_usd, :decimal
    field :total_net_worth_usd, :decimal
    field :total_savings_usd, :decimal
    field :total_yield_usd, :decimal

    # Cotizaciones al momento del cierre
    field :exchange_rate_blue, :decimal
    field :exchange_rate_mep, :decimal

    field :deleted_at, :utc_datetime

    belongs_to :user, PerfiDelta.Accounts.User
    has_many :account_balances, PerfiDelta.Finance.AccountBalance
    has_many :investment_flows, PerfiDelta.Finance.InvestmentFlow

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  @doc false
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :month,
      :year,
      :status,
      :total_income_usd,
      :total_net_worth_usd,
      :total_savings_usd,
      :total_yield_usd,
      :exchange_rate_blue,
      :exchange_rate_mep,
      :user_id
    ])
    |> validate_required([:month, :year, :user_id])
    |> validate_inclusion(:month, 1..12)
    |> validate_number(:year, greater_than: 2000, less_than: 2100)
    |> unique_constraint([:user_id, :month, :year],
      name: :snapshots_user_id_month_year_index,
      message: "ya existe un snapshot para este mes"
    )
    |> foreign_key_constraint(:user_id)
  end

  def confirm_changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :total_income_usd,
      :total_net_worth_usd,
      :total_savings_usd,
      :total_yield_usd,
      :exchange_rate_blue,
      :exchange_rate_mep
    ])
    |> put_change(:status, :confirmed)
    |> validate_required([
      :total_income_usd,
      :total_net_worth_usd,
      :exchange_rate_blue
    ])
  end

  def soft_delete_changeset(snapshot) do
    change(snapshot, deleted_at: DateTime.utc_now(:second))
  end
end
