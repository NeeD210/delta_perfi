defmodule PerfiDelta.Repo.Migrations.AddOnboardingToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :onboarding_step, :integer, default: 1
      add :onboarding_completed, :boolean, default: false
    end
  end
end
