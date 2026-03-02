defmodule Decidulixir.CLI.Commands.Writeup do
  @moduledoc "Generate PR writeup from graph."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "writeup"

  @impl true
  def description, do: "Generate PR writeup from graph"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("writeup is not yet implemented")
    {:error, "not implemented"}
  end
end
