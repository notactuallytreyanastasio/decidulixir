defmodule Decidulixir.CLI do
  @moduledoc """
  CLI public API. Delegates to the supervised Server.
  """

  alias Decidulixir.CLI.Server

  @spec execute(String.t(), [String.t()]) :: :ok | {:error, String.t()}
  def execute(command, argv \\ []) do
    Server.execute(command, argv)
  end

  @spec help() :: :ok
  def help do
    IO.puts("decidulixir — decision graph tooling\n")
    IO.puts("Usage: mix decidulixir <command> [args]\n")
    IO.puts("Commands:")

    Server.commands()
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.each(fn {_name, module} ->
      IO.puts("  #{String.pad_trailing(module.name(), 14)} #{module.description()}")
    end)

    :ok
  end
end
