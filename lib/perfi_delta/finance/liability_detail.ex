defmodule PerfiDelta.Finance.LiabilityDetail do
  @moduledoc """
  El iceberg de deuda - detalle 1:1 con AccountBalances para tarjetas de crédito.
  Separa la deuda corriente de las cuotas futuras.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "liability_details" do
    # Lo que vence este mes (saldo del resumen)
    field :current_period_balance, :decimal
    # Cuotas futuras
    field :future_installments_balance, :decimal
    # Suma de ambos (debe coincidir con AccountBalances.amount_nominal)
    field :total_debt, :decimal
    field :deleted_at, :utc_datetime

    belongs_to :account_balance, PerfiDelta.Finance.AccountBalance

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(detail, attrs) do
    detail
    |> cast(attrs, [
      :current_period_balance,
      :future_installments_balance,
      :total_debt,
      :account_balance_id
    ])
    |> validate_required([
      :current_period_balance,
      :future_installments_balance,
      :account_balance_id
    ])
    |> calculate_total_debt()
    |> foreign_key_constraint(:account_balance_id)
  end

  defp calculate_total_debt(changeset) do
    current = get_field(changeset, :current_period_balance) || Decimal.new(0)
    future = get_field(changeset, :future_installments_balance) || Decimal.new(0)

    put_change(changeset, :total_debt, Decimal.add(current, future))
  end

  def soft_delete_changeset(detail) do
    change(detail, deleted_at: DateTime.utc_now(:second))
  end
end
