defmodule Decidulixir.CLI.Commands.Sync do
  @moduledoc "Export graph for deployment."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "sync"

  @impl true
  def description, do: "Export graph for deployment"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("sync is not yet implemented")
    {:error, "not implemented"}
  end
end
