defmodule Decidulixir.CLI.Commands.Serve do
  @moduledoc "Start web viewer."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "serve"

  @impl true
  def description, do: "Start web viewer"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("serve is not yet implemented")
    {:error, "not implemented"}
  end
end
