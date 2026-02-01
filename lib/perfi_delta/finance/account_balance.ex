defmodule PerfiDelta.Finance.AccountBalance do
  @moduledoc """
  El detalle del saldo de cada cuenta en un snapshot específico.
  Si account.type == :liability, el valor es negativo.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "account_balances" do
    # Valor nominal en la moneda original (ej: 150,000 ARS)
    field :amount_nominal, :decimal
    # Valor normalizado a USD al día del cierre
    field :amount_usd, :decimal
    field :deleted_at, :utc_datetime

    belongs_to :snapshot, PerfiDelta.Finance.Snapshot
    belongs_to :account, PerfiDelta.Finance.FinancialAccount
    has_one :liability_detail, PerfiDelta.Finance.LiabilityDetail

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(balance, attrs) do
    balance
    |> cast(attrs, [:amount_nominal, :amount_usd, :snapshot_id, :account_id])
    |> validate_required([:amount_nominal, :amount_usd, :snapshot_id, :account_id])
    |> foreign_key_constraint(:snapshot_id)
    |> foreign_key_constraint(:account_id)
  end

  def soft_delete_changeset(balance) do
    change(balance, deleted_at: DateTime.utc_now(:second))
  end
end
