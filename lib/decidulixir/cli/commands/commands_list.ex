defmodule Decidulixir.CLI.Commands.CommandsList do
  @moduledoc "List all available commands."

  @behaviour Decidulixir.CLI.Command

  @impl true
  def name, do: "commands"

  @impl true
  def description, do: "List all available commands"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    alias Decidulixir.CLI.Server

    Server.commands()
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.each(fn {_name, module} ->
      IO.puts("  #{String.pad_trailing(module.name(), 14)} #{module.description()}")
    end)

    :ok
  end
end
