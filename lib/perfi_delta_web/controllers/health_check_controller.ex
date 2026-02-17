defmodule PerfiDeltaWeb.HealthCheckController do
  use PerfiDeltaWeb, :controller

  def index(conn, _params) do
    text(conn, "OK")
  end
end
