defmodule Decidulixir.CLI.Commands.Backup do
  @moduledoc "Backup the graph database."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "backup"

  @impl true
  def description, do: "Backup the graph database"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("backup is not yet implemented")
    {:error, "not implemented"}
  end
end
