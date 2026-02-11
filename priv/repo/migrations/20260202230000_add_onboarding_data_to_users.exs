defmodule PerfiDelta.Repo.Migrations.AddOnboardingDataToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :onboarding_data, :map, default: %{}
    end
  end
end
