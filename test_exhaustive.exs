# Exhaustive test script for decimal fix
defmodule TestExhaustive do
  def run do
    parse = fn str ->
      if str == "" or is_nil(str) do
        Decimal.new(0)
      else
        if String.contains?(str, ",") do
          str
          |> String.replace(".", "")
          |> String.replace(",", ".")
          |> Decimal.new()
        else
          # Handle potential dot as decimal if no comma present
          Decimal.new(str)
        end
      end
    end

    format = fn val ->
      val |> Decimal.to_string() |> String.replace(".", ",")
    end

    test_cases = [
      {"10,50", "10,5", Decimal.new("10.5")},
      {"1.234,56", "1234,56", Decimal.new("1234.56")},
      {"10.5", "10,5", Decimal.new("10.5")},  # The "Buggy" case before
      {"1000", "1000", Decimal.new("1000")},
      {"0,01", "0,01", Decimal.new("0.01")},
      {"0.01", "0,01", Decimal.new("0.01")},
      {"", "0", Decimal.new("0")}
    ]

    IO.puts "| Input | Expected Parse | Actual Parse | Expected Format | Actual Format | Result |"
    IO.puts "|-------|----------------|--------------|-----------------|---------------|--------|"

    Enum.each(test_cases, fn {input, exp_format, exp_parse} ->
      parsed = parse.(input)
      formatted = format.(parsed)
      
      parse_ok = Decimal.eq?(parsed, exp_parse)
      format_ok = formatted == exp_format
      
      result = if parse_ok and format_ok, do: "✅ PASS", else: "❌ FAIL"
      
      IO.puts "| #{input} | #{exp_parse} | #{parsed} | #{exp_format} | #{formatted} | #{result} |"
    end)
  end
end

TestExhaustive.run()
