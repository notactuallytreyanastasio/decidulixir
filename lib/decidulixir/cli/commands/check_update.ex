defmodule Decidulixir.CLI.Commands.CheckUpdate do
  @moduledoc "Check for updates."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "check-update"

  @impl true
  def description, do: "Check for updates"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("check-update is not yet implemented")
    {:error, "not implemented"}
  end
end
