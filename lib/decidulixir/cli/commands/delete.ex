defmodule Decidulixir.CLI.Commands.Delete do
  @moduledoc "Delete a node and its edges."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.Graph

  @impl true
  def name, do: "delete"

  @impl true
  def description, do: "Delete a node: delete <id> [--dry-run]"

  @impl true
  def parse(argv) do
    {opts, args, _invalid} =
      OptionParser.parse(argv, strict: [dry_run: :boolean])

    %{
      id: parse_int(List.first(args)),
      dry_run: opts[:dry_run] || false
    }
  end

  @impl true
  def execute(%{id: nil}) do
    Logger.error("Usage: delete <id> [--dry-run]")
    {:error, "missing arguments"}
  end

  def execute(%{id: {:error, val}}) do
    Logger.error("Invalid ID: #{val}. Must be integer.")
    {:error, "invalid ID"}
  end

  def execute(%{id: id, dry_run: true}) when is_integer(id) do
    case Graph.delete_node(id, dry_run: true) do
      {:ok, result} ->
        Logger.info("Would delete node #{id} (\"#{result.node.title}\") and #{result.edges_removed} edge(s)")
        :ok

      {:error, :not_found} ->
        Logger.error("Node #{id} not found")
        {:error, "not found"}
    end
  end

  def execute(%{id: id, dry_run: false}) when is_integer(id) do
    case Graph.delete_node(id) do
      {:ok, result} ->
        Logger.info("Deleted node #{id} (\"#{result.node.title}\") and #{result.edges_removed} edge(s)")
        :ok

      {:error, :not_found} ->
        Logger.error("Node #{id} not found")
        {:error, "not found"}
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> {:error, str}
    end
  end
end
