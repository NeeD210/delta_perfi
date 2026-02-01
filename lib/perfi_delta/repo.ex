defmodule PerfiDelta.Repo do
  use Ecto.Repo,
    otp_app: :perfi_delta,
    adapter: Ecto.Adapters.Postgres
end
