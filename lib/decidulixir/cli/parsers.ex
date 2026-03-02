defmodule Decidulixir.CLI.Parsers do
  @moduledoc """
  Shared parsing helpers for CLI command modules.

  Extracted from individual command modules to eliminate duplication.
  Import the functions you need:

      import Decidulixir.CLI.Parsers, only: [parse_int: 1]
  """

  @doc """
  Parses a string as an integer.

  Returns `nil` for nil input, the integer for valid input,
  or `{:error, original_string}` for invalid input.
  """
  @spec parse_int(String.t() | nil) :: integer() | nil | {:error, String.t()}
  def parse_int(nil), do: nil

  def parse_int(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> {:error, str}
    end
  end
end
