defmodule Decidulixir.CLI.Commands.Prompt do
  @moduledoc "Set or update a node's prompt in metadata."

  @behaviour Decidulixir.CLI.Command

  require Logger

  import Decidulixir.CLI.Parsers, only: [parse_int: 1]

  alias Decidulixir.CLI.Formatter
  alias Decidulixir.Graph

  @impl true
  def name, do: "prompt"

  @impl true
  def description, do: "Set prompt: prompt <id> \"text\""

  @impl true
  def parse(argv) do
    {_opts, args, _invalid} = OptionParser.parse(argv, strict: [])

    %{
      id: parse_int(List.first(args)),
      text: args |> Enum.drop(1) |> Enum.join(" ")
    }
  end

  @impl true
  def execute(%{id: nil}) do
    Logger.error("Usage: prompt <id> \"text\"")
    {:error, "missing arguments"}
  end

  def execute(%{text: ""}) do
    Logger.error("Prompt text is required")
    {:error, "missing prompt"}
  end

  def execute(%{id: {:error, val}}) do
    Logger.error("Invalid ID: #{val}. Must be integer.")
    {:error, "invalid ID"}
  end

  def execute(%{id: id, text: text}) when is_integer(id) do
    case Graph.update_node_prompt(id, text) do
      {:ok, _node} ->
        Logger.info("Updated prompt for node #{id}")
        :ok

      {:error, changeset} ->
        Logger.error("Failed to update prompt: #{Formatter.format_changeset_errors(changeset)}")
        {:error, "update failed"}
    end
  end
end
