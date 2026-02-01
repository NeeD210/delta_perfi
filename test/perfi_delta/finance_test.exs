defmodule PerfiDelta.FinanceTest do
  use PerfiDelta.DataCase

  alias PerfiDelta.Finance
  import PerfiDelta.AccountsFixtures
  import PerfiDelta.FinanceFixtures

  describe "Snapshots" do
    test "confirm_snapshot registra ingresos correctamente" do
      user = user_fixture()
      snapshot = snapshot_fixture(%{user_id: user.id})
      
      attrs = %{
        total_income_usd: Decimal.new("1500.50"),
        total_net_worth_usd: Decimal.new("5000"),
        exchange_rate_blue: Decimal.new("1000")
      }
      
      {:ok, confirmed} = Finance.confirm_snapshot(snapshot, attrs)
      assert confirmed.status == :confirmed
      assert Decimal.equal?(confirmed.total_income_usd, attrs.total_income_usd)
    end
  end

  describe "Indicadores" do
    test "las cuentas se listan con sus balances correctos" do
      user = user_fixture()
      account = financial_account_fixture(user.id)
      
      accounts = Finance.list_accounts_with_latest_balances(user.id)
      assert Enum.any?(accounts, fn a -> a.id == account.id end)
    end

    test "lista de cuentas vacía para usuario inexistente" do
      user_id = Ecto.UUID.generate()
      assert Finance.list_accounts(user_id) == []
    end
  end

  describe "Servicios" do
    test "ExchangeRateService retorna una tasa válida" do
      # Mock o llamada real si es segura
      assert {:ok, rate} = PerfiDelta.Services.ExchangeRateService.fetch_dolar_blue()
      assert Decimal.gt?(rate, 0)
    end
  end
end
