defmodule Decidulixir.CLI.Commands.Show do
  @moduledoc "Show detailed info for a single node."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.Graph

  @impl true
  def name, do: "show"

  @impl true
  def description, do: "Show node detail: show <id>"

  @impl true
  def parse(argv) do
    {opts, args, _invalid} =
      OptionParser.parse(argv, strict: [json: :boolean])

    %{
      id: parse_int(List.first(args)),
      json: opts[:json] || false
    }
  end

  @impl true
  def execute(%{id: nil}) do
    Logger.error("Usage: show <id>")
    {:error, "missing arguments"}
  end

  def execute(%{id: {:error, val}}) do
    Logger.error("Invalid ID: #{val}. Must be integer.")
    {:error, "invalid ID"}
  end

  def execute(%{id: id, json: true}) when is_integer(id) do
    case Graph.get_node(id) do
      nil -> not_found(id)
      node -> show_json(node, id)
    end
  end

  def execute(%{id: id, json: false}) when is_integer(id) do
    case Graph.get_node(id) do
      nil -> not_found(id)
      node -> show_detail(node, id)
    end
  end

  defp show_json(node, id) do
    data = %{
      node: node,
      incoming_edges: Graph.edges_to(id),
      outgoing_edges: Graph.edges_from(id)
    }

    IO.puts(Jason.encode!(data, pretty: true))
    :ok
  end

  defp show_detail(node, id) do
    incoming = Graph.edges_to(id)
    outgoing = Graph.edges_from(id)

    IO.puts("Node #{node.id}")
    IO.puts(String.duplicate("=", 40))
    IO.puts("  Type:        #{node.node_type}")
    IO.puts("  Title:       #{node.title}")
    IO.puts("  Status:      #{node.status}")
    IO.puts("  Change ID:   #{node.change_id}")
    if node.description, do: IO.puts("  Description: #{node.description}")
    print_metadata(node.metadata)
    IO.puts("  Created:     #{node.inserted_at}")
    IO.puts("  Updated:     #{node.updated_at}")
    print_edges("Incoming", "<-", incoming, :from_node_id)
    print_edges("Outgoing", "->", outgoing, :to_node_id)
    :ok
  end

  defp print_metadata(nil), do: :ok
  defp print_metadata(m) when map_size(m) == 0, do: :ok

  defp print_metadata(m) do
    IO.puts("  Metadata:")
    Enum.each(m, fn {k, v} -> IO.puts("    #{k}: #{inspect(v)}") end)
  end

  defp print_edges(_label, _arrow, [], _field), do: :ok

  defp print_edges(label, arrow, edges, field) do
    IO.puts("\n  #{label} edges (#{length(edges)}):")

    Enum.each(edges, fn edge ->
      rationale = if edge.rationale, do: " -- #{edge.rationale}", else: ""
      IO.puts("    #{arrow} #{Map.get(edge, field)} (#{edge.edge_type})#{rationale}")
    end)
  end

  defp not_found(id) do
    Logger.error("Node #{id} not found")
    {:error, "not found"}
  end

  defp parse_int(nil), do: nil
  defp parse_int(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> {:error, str}
    end
  end
end
