defmodule Decidulixir.CLI.Commands.Doc do
  @moduledoc "Manage node documents."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "doc"

  @impl true
  def description, do: "Manage node documents (attach, list, show, describe, detach, gc)"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("doc is not yet implemented")
    {:error, "not implemented"}
  end
end
