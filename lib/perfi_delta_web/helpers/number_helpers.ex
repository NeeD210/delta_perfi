defmodule PerfiDeltaWeb.Helpers.NumberHelpers do
  @moduledoc """
  Funciones centralizadas para parseo y formateo de números monetarios.
  
  ## Convención de formato
  - El servidor SIEMPRE recibe números en formato estándar: "1400.50" (punto = decimal)
  - El display usa formato argentino: "1.400,50" (punto = miles, coma = decimal)
  - La conversión display ↔ wire la maneja el JS hook `NumberFormat`
  """

  @fiat_currencies ~w(ARS USD USDT)

  @doc """
  Parsea un string numérico a Decimal.
  Espera formato estándar del wire: "1400", "1400.50", "0.00012345"
  
  NO intenta adivinar formatos ambiguos — eso es responsabilidad del JS hook.

  ## Ejemplos
      iex> parse_currency("1400.50")
      Decimal.new("1400.50")

      iex> parse_currency("1400")
      Decimal.new("1400")

      iex> parse_currency("")
      Decimal.new("0")
  """
  def parse_currency(nil), do: Decimal.new(0)
  def parse_currency(""), do: Decimal.new(0)

  def parse_currency(str) when is_binary(str) do
    str
    |> String.trim()
    |> Decimal.new()
  rescue
    _ -> Decimal.new(0)
  end

  def parse_currency(_), do: Decimal.new(0)

  @doc """
  Formatea un Decimal para display.

  ## Opciones
    - `:currency` - La moneda para determinar el formato (default: "USD")

  Para monedas fiat (ARS, USD, USDT): redondea a enteros con separadores de miles.
  Para cripto (BTC, ETH, SOL): muestra hasta 8 decimales significativos.

  ## Ejemplos
      iex> format_currency(Decimal.new("1400.50"), currency: "USD")
      "1.401"

      iex> format_currency(Decimal.new("0.00012345"), currency: "BTC")
      "0,00012345"
  """
  def format_currency(decimal, opts \\ [])
  def format_currency(nil, _opts), do: "0"

  def format_currency(decimal, opts) do
    currency = Keyword.get(opts, :currency, "USD")

    if currency in @fiat_currencies do
      format_fiat(decimal)
    else
      format_crypto(decimal)
    end
  end

  @doc """
  Formato inteligente para valores en inputs de balance.
  Devuelve el valor en formato wire (punto decimal) que el JS hook formateará para display.
  - Números >= 1: redondea a entero ("1400")
  - Números < 1: mantiene decimales significativos ("0.00012")
  """
  def format_smart_currency(nil), do: ""

  def format_smart_currency(decimal) when is_struct(decimal, Decimal) do
    if Decimal.compare(Decimal.abs(decimal), Decimal.new(1)) == :lt do
      # Número menor a 1: mantener decimales significativos
      Decimal.to_string(decimal)
      |> String.replace(~r/0+$/, "")
      |> String.replace(~r/\.$/, "")
    else
      # Número >= 1: redondear a entero
      decimal
      |> Decimal.round(0)
      |> Decimal.to_string()
    end
  end

  def format_smart_currency(value), do: to_string(value)

  @doc """
  Formatea un Decimal con signo +/- para mostrar deltas (ahorro, rendimiento).

  ## Ejemplos
      iex> format_signed(Decimal.new("1400"))
      "+$1.400"

      iex> format_signed(Decimal.new("-500"))
      "-$500"
  """
  def format_signed(nil), do: "$0"

  def format_signed(decimal) do
    cond do
      Decimal.positive?(decimal) -> "+$#{format_fiat(decimal)}"
      Decimal.negative?(decimal) -> "-$#{format_fiat(Decimal.abs(decimal))}"
      true -> "$0"
    end
  end

  @doc """
  Formatea un Decimal como tasa de cambio (ej: dólar blue).
  """
  def format_rate(nil), do: "-"
  def format_rate(rate), do: rate |> Decimal.round(0) |> Decimal.to_string()

  # --- Private Helpers ---

  defp format_fiat(decimal) do
    decimal
    |> Decimal.round(0)
    |> Decimal.to_string()
    |> add_thousands_separator()
  end

  defp format_crypto(decimal) do
    # Para cripto, mostrar hasta 8 decimales significativos
    str = Decimal.to_string(decimal)

    case String.split(str, ".") do
      [int] ->
        # Sin decimales
        add_thousands_separator(int)

      [int, dec] ->
        # Con decimales - mantener los significativos (hasta 8)
        trimmed_dec = String.slice(dec, 0, 8) |> String.trim_trailing("0")

        if trimmed_dec == "" do
          add_thousands_separator(int)
        else
          # Formato argentino: coma para decimales
          "#{add_thousands_separator(int)},#{trimmed_dec}"
        end
    end
  end

  @doc false
  def add_thousands_separator(str) when is_binary(str) do
    # Manejar números negativos
    {sign, abs_str} =
      if String.starts_with?(str, "-") do
        {"-", String.slice(str, 1..-1//1)}
      else
        {"", str}
      end

    formatted =
      abs_str
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.join(".")
      |> String.reverse()

    sign <> formatted
  end
end
