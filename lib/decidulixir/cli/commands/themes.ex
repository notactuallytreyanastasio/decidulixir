defmodule Decidulixir.CLI.Commands.Themes do
  @moduledoc "Manage graph themes."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "themes"

  @impl true
  def description, do: "Manage graph themes"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    Logger.warning("themes is not yet implemented")
    {:error, "not implemented"}
  end
end
