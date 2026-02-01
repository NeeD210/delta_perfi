defmodule PerfiDelta.Repo.Migrations.CreateFinanceTables do
  use Ecto.Migration

  def change do
    # Agregar deleted_at a users
    alter table(:users) do
      add :deleted_at, :utc_datetime
    end

    # Financial Accounts (El Inventario)
    create table(:financial_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false
      add :currency, :string, null: false
      add :is_automated, :boolean, default: false, null: false
      add :deleted_at, :utc_datetime

      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:financial_accounts, [:user_id])
    create index(:financial_accounts, [:user_id, :type])

    # Snapshots (La Foto Mensual)
    create table(:snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :month, :integer, null: false
      add :year, :integer, null: false
      add :status, :string, default: "draft", null: false

      add :total_income_usd, :decimal, precision: 18, scale: 2
      add :total_net_worth_usd, :decimal, precision: 18, scale: 2
      add :total_savings_usd, :decimal, precision: 18, scale: 2
      add :total_yield_usd, :decimal, precision: 18, scale: 2

      add :exchange_rate_blue, :decimal, precision: 12, scale: 2
      add :exchange_rate_mep, :decimal, precision: 12, scale: 2

      add :deleted_at, :utc_datetime

      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:snapshots, [:user_id])
    create unique_index(:snapshots, [:user_id, :month, :year])

    # Account Balances (El Detalle)
    create table(:account_balances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :amount_nominal, :decimal, precision: 18, scale: 8, null: false
      add :amount_usd, :decimal, precision: 18, scale: 2, null: false
      add :deleted_at, :utc_datetime

      add :snapshot_id, references(:snapshots, on_delete: :delete_all, type: :binary_id), null: false
      add :account_id, references(:financial_accounts, on_delete: :restrict, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:account_balances, [:snapshot_id])
    create index(:account_balances, [:account_id])
    create unique_index(:account_balances, [:snapshot_id, :account_id])

    # Liability Details (El Iceberg de Deuda)
    create table(:liability_details, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :current_period_balance, :decimal, precision: 18, scale: 2, null: false
      add :future_installments_balance, :decimal, precision: 18, scale: 2, null: false
      add :total_debt, :decimal, precision: 18, scale: 2, null: false
      add :deleted_at, :utc_datetime

      add :account_balance_id, references(:account_balances, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:liability_details, [:account_balance_id])

    # Investment Flows (La Corrección)
    create table(:investment_flows, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :amount_usd, :decimal, precision: 18, scale: 2, null: false
      add :direction, :string, null: false
      add :description, :string
      add :deleted_at, :utc_datetime

      add :snapshot_id, references(:snapshots, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:investment_flows, [:snapshot_id])

    # Exchange Rates (Cache de Cotizaciones)
    create table(:exchange_rates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :currency_pair, :string, null: false
      add :source, :string, null: false
      add :rate, :decimal, precision: 18, scale: 8, null: false
      add :fetched_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:exchange_rates, [:currency_pair, :source, :fetched_at])
  end
end
