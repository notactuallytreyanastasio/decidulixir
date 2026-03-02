defmodule Decidulixir.CLI.Commands.Update do
  @moduledoc "Update the installed deciduous version marker."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "update"

  @impl true
  def description, do: "Update deciduous version marker"

  @impl true
  def parse(_argv), do: %{}

  @impl true
  def execute(_config) do
    if File.dir?(".deciduous") do
      version = Mix.Project.config()[:version] || "0.0.0"
      File.write!(".deciduous/.version", version)
      Logger.info("Updated to v#{version}")
      :ok
    else
      Logger.error("Not initialized. Run 'init' first.")
      {:error, "not initialized"}
    end
  end
end
