defmodule Decidulixir.CLI.Commands.Init do
  @moduledoc "Initialize deciduous in a project."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "init"

  @impl true
  def description, do: "Initialize deciduous in a project"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("init is not yet implemented")
    {:error, "not implemented"}
  end
end
