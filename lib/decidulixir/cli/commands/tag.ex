defmodule Decidulixir.CLI.Commands.Tag do
  @moduledoc "Tag nodes."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "tag"

  @impl true
  def description, do: "Tag nodes"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("tag is not yet implemented")
    {:error, "not implemented"}
  end
end
