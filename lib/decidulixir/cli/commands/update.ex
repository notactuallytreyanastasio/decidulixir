defmodule Decidulixir.CLI.Commands.Update do
  @moduledoc "Update deciduous configuration."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "update"

  @impl true
  def description, do: "Update deciduous configuration"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("update is not yet implemented")
    {:error, "not implemented"}
  end
end
