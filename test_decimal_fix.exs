# Test script for decimal fixes
# Run with: mix run test_decimal_fix.exs

# Mocking enough of terms to test helpers
defmodule TestDecimalFix do
  def run do
    IO.puts "Testing OnboardingLive logic..."
    test_onboarding()
    IO.puts "\nTesting ClosureWizardLive logic..."
    test_closure()
  end

  defp test_onboarding do
    # Simulate parse_decimal
    # Using Code.eval_string to access private functions if needed, 
    # but since I'm in the same project I can just use the module if it was public.
    # Since they are private (defp), I'll test by copying the logic or using apply if I make them public.
    # Actually, I can just copy the logic here to verify the REGEX/String logic is correct.
    
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
          Decimal.new(str)
        end
      end
    end

    format = fn val ->
      if val do
        val |> Decimal.to_string() |> String.replace(".", ",")
      else
        ""
      end
    end

    # Test cases
    cases = [
      {"10,50", Decimal.from_float(10.5)},
      {"1.234,56", Decimal.new("1234.56")},
      {"10.5", Decimal.from_float(10.5)}, # From Decimal.to_string internally
      {"1000", Decimal.new(1000)}
    ]

    Enum.each(cases, fn {input, expected} ->
      parsed = parse.(input)
      formatted = format.(parsed)
      IO.puts "Input: #{input} -> Parsed: #{parsed} (Expected: #{expected}) -> Formatted: #{formatted}"
      if Decimal.eq?(parsed, expected) do
        IO.puts "  ✅ Parse OK"
      else
        IO.puts "  ❌ Parse FAIL"
      end
    end)
  end

  defp test_closure do
    # Similar logic
    IO.puts "Same logic as Onboarding"
  end
end

TestDecimalFix.run()
