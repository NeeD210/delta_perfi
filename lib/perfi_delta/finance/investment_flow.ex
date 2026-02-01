defmodule PerfiDelta.Finance.InvestmentFlow do
  @moduledoc """
  La corrección - dinero nuevo inyectado o retirado del sistema de inversiones.
  Necesario para calcular el rendimiento real (Yield).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @directions [:deposit, :withdrawal]

  schema "investment_flows" do
    field :amount_usd, :decimal
    field :direction, Ecto.Enum, values: @directions
    field :description, :string
    field :deleted_at, :utc_datetime

    belongs_to :snapshot, PerfiDelta.Finance.Snapshot

    timestamps(type: :utc_datetime)
  end

  def directions, do: @directions

  @doc false
  def changeset(flow, attrs) do
    flow
    |> cast(attrs, [:amount_usd, :direction, :description, :snapshot_id])
    |> validate_required([:amount_usd, :direction, :snapshot_id])
    |> validate_number(:amount_usd, greater_than: 0)
    |> validate_inclusion(:direction, @directions)
    |> foreign_key_constraint(:snapshot_id)
  end

  @doc """
  Retorna el monto con signo según la dirección.
  Deposits son positivos, withdrawals son negativos.
  """
  def signed_amount(%__MODULE__{amount_usd: amount, direction: :deposit}), do: amount
  def signed_amount(%__MODULE__{amount_usd: amount, direction: :withdrawal}), do: Decimal.negate(amount)

  def soft_delete_changeset(flow) do
    change(flow, deleted_at: DateTime.utc_now(:second))
  end
end
