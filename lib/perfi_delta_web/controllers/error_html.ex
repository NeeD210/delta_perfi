defmodule PerfiDeltaWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use PerfiDeltaWeb, :html

  # Custom error pages in Spanish
  embed_templates "error_html/*"
end
