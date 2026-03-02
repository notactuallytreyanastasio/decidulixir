defmodule Decidulixir.CLI.Commands.Hooks do
  @moduledoc "Manage git hooks."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "hooks"

  @impl true
  def description, do: "Manage git hooks"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("hooks is not yet implemented")
    {:error, "not implemented"}
  end
end
