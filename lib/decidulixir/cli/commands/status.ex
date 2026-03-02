defmodule Decidulixir.CLI.Commands.Status do
  @moduledoc "Update a node's status."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.CLI.Formatter
  alias Decidulixir.Graph
  alias Decidulixir.Graph.Node

  @status_strings Map.new(Node.node_statuses(), fn s -> {Atom.to_string(s), s} end)

  @impl true
  def name, do: "status"

  @impl true
  def description, do: "Set node status: status <id> <status>"

  @impl true
  def parse(argv) do
    {_opts, args, _invalid} = OptionParser.parse(argv, strict: [])

    %{
      id: parse_int(Enum.at(args, 0)),
      status: parse_status(Enum.at(args, 1))
    }
  end

  @impl true
  def execute(%{id: nil}) do
    Logger.error("Usage: status <id> <status> (valid: #{valid_statuses()})")
    {:error, "missing arguments"}
  end

  def execute(%{status: nil}) do
    Logger.error("Usage: status <id> <status> (valid: #{valid_statuses()})")
    {:error, "missing arguments"}
  end

  def execute(%{status: {:error, str}}) do
    Logger.error("Invalid status: #{str} (valid: #{valid_statuses()})")
    {:error, "invalid status"}
  end

  def execute(%{id: {:error, val}}) do
    Logger.error("Invalid ID: #{val}. Must be integer.")
    {:error, "invalid ID"}
  end

  def execute(%{id: id, status: status}) when is_integer(id) and is_atom(status) do
    case Graph.update_node_status(id, status) do
      {:ok, node} ->
        Logger.info("Updated node #{node.id} status to '#{status}'")
        :ok

      {:error, changeset} ->
        Logger.error("Failed to update status: #{Formatter.format_changeset_errors(changeset)}")
        {:error, "update failed"}
    end
  end

  defp valid_statuses, do: Node.node_statuses() |> Enum.map_join(", ", &to_string/1)

  defp parse_status(nil), do: nil

  defp parse_status(str) do
    case Map.fetch(@status_strings, str) do
      {:ok, status} -> status
      :error -> {:error, str}
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
