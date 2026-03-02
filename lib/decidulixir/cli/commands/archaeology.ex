defmodule Decidulixir.CLI.Commands.Archaeology do
  @moduledoc "Retroactive decision mining."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "archaeology"

  @impl true
  def description, do: "Retroactive decision mining"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("archaeology is not yet implemented")
    {:error, "not implemented"}
  end
end
