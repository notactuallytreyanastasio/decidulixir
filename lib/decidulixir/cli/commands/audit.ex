defmodule Decidulixir.CLI.Commands.Audit do
  @moduledoc "Audit the decision graph for orphans, missing connections, and issues."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.Graph

  @impl true
  def name, do: "audit"

  @impl true
  def description, do: "Audit graph for issues (orphans, missing links)"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv, strict: [json: :boolean])

    %{json: opts[:json] || false}
  end

  @impl true
  def execute(%{json: true}) do
    issues = audit()
    IO.puts(Jason.encode!(%{issues: issues, count: length(issues)}, pretty: true))
    :ok
  end

  def execute(%{json: false}) do
    audit() |> print_results()
  end

  defp print_results([]) do
    Logger.info("No issues found. Graph is clean.")
    :ok
  end

  defp print_results(issues) do
    IO.puts("Audit Results")
    IO.puts(String.duplicate("=", 30))
    Enum.each(issues, fn issue -> Logger.warning(issue) end)
    IO.puts("")
    Logger.info("#{length(issues)} issue(s) found")
    :ok
  end

  defp audit do
    nodes = Graph.list_nodes()
    edges = Graph.list_edges()
    node_ids = MapSet.new(nodes, & &1.id)
    from_ids = MapSet.new(edges, & &1.from_node_id)
    to_ids = MapSet.new(edges, & &1.to_node_id)
    connected = MapSet.union(from_ids, to_ids)

    find_orphans(nodes, connected) ++
      find_dangling_outcomes(nodes, to_ids) ++
      find_missing_refs(edges, node_ids)
  end

  defp find_orphans(nodes, connected) do
    nodes
    |> Enum.reject(fn n -> n.node_type == :goal or MapSet.member?(connected, n.id) end)
    |> Enum.map(fn n -> "Orphan: node #{n.id} (#{n.node_type}: \"#{n.title}\") has no edges" end)
  end

  defp find_dangling_outcomes(nodes, to_ids) do
    nodes
    |> Enum.filter(fn n -> n.node_type == :outcome and not MapSet.member?(to_ids, n.id) end)
    |> Enum.map(fn n ->
      "Dangling outcome: node #{n.id} (\"#{n.title}\") has no incoming edge"
    end)
  end

  defp find_missing_refs(edges, node_ids) do
    Enum.flat_map(edges, fn edge ->
      check_ref(edge, :from_node_id, node_ids) ++ check_ref(edge, :to_node_id, node_ids)
    end)
  end

  defp check_ref(edge, field, node_ids) do
    id = Map.get(edge, field)

    case MapSet.member?(node_ids, id) do
      true -> []
      false -> ["Broken edge #{edge.id}: #{field} #{id} does not exist"]
    end
  end
end
