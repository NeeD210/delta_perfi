defmodule PerfiDelta.Services.ExchangeRateService do
  @moduledoc """
  Servicio para obtener cotizaciones de APIs externas.
  - Dólar Blue/MEP: DolarApi (dolarapi.com/v1/dolares; casa "blue" y "bolsa", campo "venta")
  - Crypto: Binance
  """

  alias PerfiDelta.Finance

  @dolar_api_url "https://dolarapi.com/v1/dolares"
  @binance_api_url "https://api.binance.com/api/v3/ticker/price"

  # Cache de 5 minutos para evitar saturar las APIs
  @cache_ttl_seconds 300

  @doc """
  Obtiene todas las cotizaciones necesarias.
  Retorna un mapa con las tasas.
  """
  def fetch_all_rates do
    with {:ok, dolar_rates} <- fetch_dolar_rates(),
         {:ok, crypto_rates} <- fetch_crypto_rates() do
      {:ok, Map.merge(dolar_rates, crypto_rates)}
    end
  end

  @doc "Obtiene cotización del dólar blue"
  def fetch_dolar_blue do
    case get_cached_rate("USD_ARS", "dolarapi_blue") do
      {:ok, rate} ->
        {:ok, rate}

      :stale ->
        fetch_and_cache_dolar_rates()
        |> case do
          {:ok, rates} -> {:ok, rates.blue}
          error -> error
        end
    end
  end

  @doc "Obtiene cotización del dólar MEP"
  def fetch_dolar_mep do
    case get_cached_rate("USD_ARS", "dolarapi_mep") do
      {:ok, rate} ->
        {:ok, rate}

      :stale ->
        fetch_and_cache_dolar_rates()
        |> case do
          {:ok, rates} -> {:ok, rates.mep}
          error -> error
        end
    end
  end

  @doc "Convierte un monto de una moneda a USD"
  def convert_to_usd(amount, "USD"), do: {:ok, amount}
  def convert_to_usd(amount, "USDT"), do: {:ok, amount}

  def convert_to_usd(amount, "ARS") do
    case fetch_dolar_blue() do
      {:ok, rate} ->
        usd = Decimal.div(amount, rate)
        {:ok, usd}

      error ->
        error
    end
  end

  def convert_to_usd(amount, currency) when currency in ["BTC", "ETH", "SOL"] do
    case fetch_crypto_price(currency) do
      {:ok, price_usd} ->
        usd = Decimal.mult(amount, price_usd)
        {:ok, usd}

      error ->
        error
    end
  end

  def convert_to_usd(_amount, currency) do
    {:error, "Moneda no soportada: #{currency}"}
  end

  # ==============================================================================
  # Private Functions
  # ==============================================================================

  defp fetch_dolar_rates do
    case fetch_and_cache_dolar_rates() do
      {:ok, rates} -> {:ok, rates}
      error -> error
    end
  end

  defp fetch_and_cache_dolar_rates do
    case http_get(@dolar_api_url) do
      {:ok, body} ->
        rates = parse_dolar_response(body)
        cache_dolar_rates(rates)
        {:ok, rates}

      {:error, reason} ->
        # Intentar usar cache expirado como fallback
        case get_cached_rate("USD_ARS", "dolarapi_blue", allow_expired: true) do
          {:ok, _} = cached -> cached
          _ -> {:error, reason}
        end
    end
  end

  defp parse_dolar_response(body) do
    dolares = Jason.decode!(body)

    blue =
      dolares
      |> Enum.find(fn d -> d["casa"] == "blue" end)
      |> get_venta_rate()

    mep =
      dolares
      |> Enum.find(fn d -> d["casa"] == "bolsa" end)
      |> get_venta_rate()

    oficial =
      dolares
      |> Enum.find(fn d -> d["casa"] == "oficial" end)
      |> get_venta_rate()

    %{
      blue: blue,
      mep: mep,
      oficial: oficial
    }
  end

  defp get_venta_rate(nil), do: Decimal.new(0)
  defp get_venta_rate(%{"venta" => venta}), do: Decimal.new(to_string(venta))

  defp cache_dolar_rates(%{blue: blue, mep: mep, oficial: oficial}) do
    now = DateTime.utc_now(:second)

    Finance.save_exchange_rate(%{
      currency_pair: "USD_ARS",
      source: "dolarapi_blue",
      rate: blue,
      fetched_at: now
    })

    Finance.save_exchange_rate(%{
      currency_pair: "USD_ARS",
      source: "dolarapi_mep",
      rate: mep,
      fetched_at: now
    })

    Finance.save_exchange_rate(%{
      currency_pair: "USD_ARS",
      source: "dolarapi_oficial",
      rate: oficial,
      fetched_at: now
    })
  end

  defp fetch_crypto_rates do
    symbols = ["BTCUSDT", "ETHUSDT", "SOLUSDT"]
    symbols_param = Jason.encode!(symbols)
    url = "#{@binance_api_url}?symbols=#{URI.encode(symbols_param)}"

    case http_get(url) do
      {:ok, body} ->
        rates = parse_crypto_response(body)
        cache_crypto_rates(rates)
        {:ok, rates}

      {:error, reason} ->
        # Fallback a cache
        {:error, reason}
    end
  end

  defp parse_crypto_response(body) do
    prices = Jason.decode!(body)

    Enum.reduce(prices, %{}, fn %{"symbol" => symbol, "price" => price}, acc ->
      key = symbol |> String.replace("USDT", "") |> String.downcase() |> String.to_atom()
      Map.put(acc, key, Decimal.new(price))
    end)
  end

  defp cache_crypto_rates(rates) do
    now = DateTime.utc_now(:second)

    Enum.each(rates, fn {currency, rate} ->
      Finance.save_exchange_rate(%{
        currency_pair: "#{String.upcase(to_string(currency))}_USD",
        source: "binance",
        rate: rate,
        fetched_at: now
      })
    end)
  end

  defp fetch_crypto_price(currency) do
    symbol = "#{currency}USDT"
    url = "#{@binance_api_url}?symbol=#{symbol}"

    case http_get(url) do
      {:ok, body} ->
        %{"price" => price} = Jason.decode!(body)
        {:ok, Decimal.new(price)}

      error ->
        error
    end
  end

  defp get_cached_rate(pair, source, opts \\ []) do
    case Finance.get_latest_rate(pair, source) do
      nil ->
        :stale

      rate ->
        age = DateTime.diff(DateTime.utc_now(), rate.fetched_at, :second)

        if age < @cache_ttl_seconds or Keyword.get(opts, :allow_expired, false) do
          {:ok, rate.rate}
        else
          :stale
        end
    end
  end

  defp http_get(url) do
    # Usando Req que viene incluido en Phoenix 1.8
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %{status: 200, body: body}} when is_list(body) or is_map(body) ->
        {:ok, Jason.encode!(body)}

      {:ok, %{status: status}} ->
        {:error, "HTTP error: #{status}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end
end
