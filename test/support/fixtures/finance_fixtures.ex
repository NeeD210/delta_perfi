defmodule PerfiDelta.FinanceFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PerfiDelta.Finance` context.
  """

  alias PerfiDelta.Finance

  def snapshot_fixture(attrs \\ %{}) do
    {:ok, snapshot} =
      attrs
      |> Enum.into(%{
        month: 1,
        year: 2024,
        status: :draft
      })
      |> Finance.create_snapshot()

    snapshot
  end

  def financial_account_fixture(user_id, attrs \\ %{}) do
    {:ok, account} =
      attrs
      |> Enum.into(%{
        name: "Cuenta de Prueba",
        type: :liquid,
        currency: "ARS",
        user_id: user_id
      })
      |> Finance.create_account()

    account
  end
end
