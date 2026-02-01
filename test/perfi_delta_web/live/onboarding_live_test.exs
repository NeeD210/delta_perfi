defmodule PerfiDeltaWeb.OnboardingLiveTest do
  use PerfiDeltaWeb.ConnCase
  import Phoenix.LiveViewTest
  import PerfiDelta.AccountsFixtures
  import PerfiDelta.FinanceFixtures

  alias PerfiDelta.Finance

  describe "Onboarding wizard" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "navega por los pasos del wizard hasta el final", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/onboarding")

      # Paso 1: Bienvenida
      assert render(lv) =~ "Bienvenido a PerFi Delta"
      lv |> element("button", "Comenzar") |> render_click()
      
      # Paso 2: Personalización (Seleccionamos todo para ir por el camino largo)
      lv |> element("button", "Tengo Inversiones") |> render_click()
      lv |> element("button", "Tengo Deudas") |> render_click()
      lv |> element("button", "Siguiente") |> render_click()

      # Paso 3, 4, 5, 6 (Siguiente)
      # 3: Liquid, 4: Inversiones, 5: Deudas, 6: Balances
      for _ <- 3..6 do
        lv |> element("button", "Siguiente") |> render_click()
      end

      # Ahora deberíamos estar en Paso 7: Ingresos
      assert render(lv) =~ "Ingresos Mensuales"
    end

    test "completa el onboarding exitosamente", %{conn: conn, user: user} do
      # Creamos una cuenta antes para que el botón de finalizar esté habilitado
      Finance.create_account(%{name: "Efectivo", type: :liquid, currency: "ARS", user_id: user.id})

      {:ok, lv, _html} = live(conn, ~p"/onboarding")

      # Paso 1: Comenzar
      lv |> element("button", "Comenzar") |> render_click()

      # Paso 2: Toggle
      lv |> element("button", "Tengo Inversiones") |> render_click()
      lv |> element("button", "Tengo Deudas") |> render_click()
      lv |> element("button", "Siguiente") |> render_click()

      # Pasos 3 al 7 (Siguiente)
      for _ <- 3..7 do
        lv |> element("button", "Siguiente") |> render_click()
      end

      # Paso 8: Finalizar
      lv |> element("button", "Completar Setup") |> render_click()
      
      # Verificar que se creó el snapshot
      snapshot = Finance.get_latest_confirmed_snapshot(user.id)
      assert snapshot.status == :confirmed
    end
  end
end
