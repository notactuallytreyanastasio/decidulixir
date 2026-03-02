defmodule Decidulixir.CLI.Commands.Narratives do
  @moduledoc "Track decision narratives."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "narratives"

  @impl true
  def description, do: "Track decision narratives"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("narratives is not yet implemented")
    {:error, "not implemented"}
  end
end
