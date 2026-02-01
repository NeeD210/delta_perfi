defmodule PerfiDelta.Finance.FinancialAccount do
  @moduledoc """
  Representa dónde está el dinero o la deuda del usuario.
  Ejemplos: "Galicia", "Binance BTC", "Visa"
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @account_types [:liquid, :investment, :liability]

  schema "financial_accounts" do
    field :name, :string
    field :type, Ecto.Enum, values: @account_types
    field :currency, :string
    field :is_automated, :boolean, default: false
    field :deleted_at, :utc_datetime

    belongs_to :user, PerfiDelta.Accounts.User
    has_many :balances, PerfiDelta.Finance.AccountBalance, foreign_key: :account_id

    timestamps(type: :utc_datetime)
  end

  def account_types, do: @account_types

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :type, :currency, :is_automated, :user_id])
    |> validate_required([:name, :type, :currency, :user_id])
    |> validate_inclusion(:type, @account_types)
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:currency, min: 2, max: 10)
    |> foreign_key_constraint(:user_id)
  end

  def soft_delete_changeset(account) do
    change(account, deleted_at: DateTime.utc_now(:second))
  end
end
