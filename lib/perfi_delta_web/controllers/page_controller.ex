defmodule PerfiDeltaWeb.PageController do
  use PerfiDeltaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def redirect_to_landing(conn, _params) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      redirect(conn, to: ~p"/dashboard")
    else
      redirect(conn, to: ~p"/landing")
    end
  end
end
