defmodule PerfiDeltaWeb.PageController do
  use PerfiDeltaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
