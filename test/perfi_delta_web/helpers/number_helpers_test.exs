defmodule PerfiDeltaWeb.Helpers.NumberHelpersTest do
  use ExUnit.Case, async: true

  alias PerfiDeltaWeb.Helpers.NumberHelpers

  describe "parse_currency/1" do
    test "parsea formato wire estándar (punto = decimal)" do
      assert NumberHelpers.parse_currency("1400.50") == Decimal.new("1400.50")
      assert NumberHelpers.parse_currency("1400") == Decimal.new("1400")
      assert NumberHelpers.parse_currency("0.00012345") == Decimal.new("0.00012345")
    end

    test "maneja strings vacíos y nil" do
      assert NumberHelpers.parse_currency("") == Decimal.new("0")
      assert NumberHelpers.parse_currency(nil) == Decimal.new("0")
    end

    test "no falla con input inválido" do
      assert NumberHelpers.parse_currency("abc") == Decimal.new("0")
      assert NumberHelpers.parse_currency("12abc34") == Decimal.new("0")
    end

    test "parsea enteros grandes" do
      assert NumberHelpers.parse_currency("1234567") == Decimal.new("1234567")
    end

    test "maneja espacios" do
      assert NumberHelpers.parse_currency("  1400  ") == Decimal.new("1400")
    end
  end

  describe "format_currency/2" do
    test "formatea fiat con separadores de miles (redondea a enteros)" do
      assert NumberHelpers.format_currency(Decimal.new("1400.50"), currency: "USD") == "1.401"
      assert NumberHelpers.format_currency(Decimal.new("1234567"), currency: "ARS") == "1.234.567"
      assert NumberHelpers.format_currency(Decimal.new("500"), currency: "USDT") == "500"
    end

    test "formatea cripto con decimales significativos" do
      assert NumberHelpers.format_currency(Decimal.new("0.00012345"), currency: "BTC") == "0,00012345"
      assert NumberHelpers.format_currency(Decimal.new("1.5"), currency: "ETH") == "1,5"
      assert NumberHelpers.format_currency(Decimal.new("100"), currency: "SOL") == "100"
    end

    test "maneja nil" do
      assert NumberHelpers.format_currency(nil, currency: "USD") == "0"
    end

    test "default es formato fiat" do
      assert NumberHelpers.format_currency(Decimal.new("1400.50")) == "1.401"
    end
  end

  describe "format_smart_currency/1" do
    test "formatea números >= 1 como enteros (wire format)" do
      assert NumberHelpers.format_smart_currency(Decimal.new("1400")) == "1400"
      assert NumberHelpers.format_smart_currency(Decimal.new("1400.80")) == "1401"
    end

    test "formatea números < 1 con decimales significativos (wire format)" do
      assert NumberHelpers.format_smart_currency(Decimal.new("0.00012345")) == "0.00012345"
      assert NumberHelpers.format_smart_currency(Decimal.new("0.5")) == "0.5"
    end

    test "maneja nil" do
      assert NumberHelpers.format_smart_currency(nil) == ""
    end

    test "maneja valores no-Decimal" do
      assert NumberHelpers.format_smart_currency(42) == "42"
    end
  end

  describe "format_signed/1" do
    test "formatea positivos con signo +" do
      assert NumberHelpers.format_signed(Decimal.new("1400")) == "+$1.400"
    end

    test "formatea negativos con signo -" do
      assert NumberHelpers.format_signed(Decimal.new("-500")) == "-$500"
    end

    test "maneja nil" do
      assert NumberHelpers.format_signed(nil) == "$0"
    end

    test "maneja cero" do
      assert NumberHelpers.format_signed(Decimal.new("0")) == "$0"
    end
  end

  describe "format_rate/1" do
    test "formatea tasa de cambio" do
      assert NumberHelpers.format_rate(Decimal.new("1234.56")) == "1235"
    end

    test "maneja nil" do
      assert NumberHelpers.format_rate(nil) == "-"
    end
  end
end
