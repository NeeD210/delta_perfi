defmodule PerfiDelta.AccountsTest do
  use PerfiDelta.DataCase

  alias PerfiDelta.Accounts
  alias PerfiDelta.Accounts.User

  import PerfiDelta.AccountsFixtures

  describe "register_user/1" do
    test "registra un usuario con datos válidos" do
      email = unique_user_email()
      attr = valid_user_attributes(email: email)
      assert {:ok, %User{email: ^email}} = Accounts.register_user(attr)
    end

    test "valida el formato del email" do
      {:error, changeset} = Accounts.register_user(%{email: "email_invalido"})
      assert %{email: ["debe tener el signo @ y no puede tener espacios"]} = errors_on(changeset)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "retorna el usuario con credenciales válidas" do
      user = user_fixture() |> set_password()
      password = valid_user_password()
      assert %User{id: id} = Accounts.get_user_by_email_and_password(user.email, password)
      assert id == user.id
    end

    test "no retorna el usuario con contraseña incorrecta" do
      user = user_fixture() |> set_password()
      refute Accounts.get_user_by_email_and_password(user.email, "incorrecta")
    end
  end
end
