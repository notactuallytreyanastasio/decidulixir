defmodule Decidulixir.CLI.Commands.Pulse do
  @moduledoc "Show graph health summary."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "pulse"

  @impl true
  def description, do: "Show graph health summary"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("pulse is not yet implemented")
    {:error, "not implemented"}
  end
end
