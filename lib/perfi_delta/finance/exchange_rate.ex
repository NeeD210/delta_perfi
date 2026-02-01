defmodule PerfiDelta.Finance.ExchangeRate do
  @moduledoc """
  Cache de cotizaciones para evitar sobrecargar APIs externas.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "exchange_rates" do
    # Ej: "USD_ARS", "BTC_USD"
    field :currency_pair, :string
    # Ej: "dolarapi_blue", "binance"
    field :source, :string
    field :rate, :decimal
    field :fetched_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rate, attrs) do
    rate
    |> cast(attrs, [:currency_pair, :source, :rate, :fetched_at])
    |> validate_required([:currency_pair, :source, :rate, :fetched_at])
    |> validate_number(:rate, greater_than: 0)
  end
end
