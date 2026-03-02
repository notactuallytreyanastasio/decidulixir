defmodule Decidulixir.CLI.Commands.Pulse do
  @moduledoc "Show graph health summary with metrics."

  @behaviour Decidulixir.CLI.Command

  alias Decidulixir.Graph

  @impl true
  def name, do: "pulse"

  @impl true
  def description, do: "Show graph health summary"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv, strict: [json: :boolean])

    %{json: opts[:json] || false}
  end

  @impl true
  def execute(%{json: true}) do
    IO.puts(Jason.encode!(build_pulse(), pretty: true))
    :ok
  end

  def execute(%{json: false}) do
    pulse = build_pulse()
    print_pulse(pulse)
    :ok
  end

  defp build_pulse do
    stats = Graph.graph_stats()
    by_type = Graph.node_counts_by_type()
    nodes = Graph.list_nodes()
    edges = Graph.list_edges()
    active_goals = Graph.active_goals()

    node_ids = MapSet.new(nodes, & &1.id)
    from_ids = MapSet.new(edges, & &1.from_node_id)
    to_ids = MapSet.new(edges, & &1.to_node_id)
    connected = MapSet.union(from_ids, to_ids)

    orphans =
      Enum.count(nodes, fn n ->
        n.node_type != :goal and not MapSet.member?(connected, n.id)
      end)

    dangling_outcomes =
      Enum.count(nodes, fn n ->
        n.node_type == :outcome and not MapSet.member?(to_ids, n.id)
      end)

    broken_edges =
      Enum.count(edges, fn e ->
        not MapSet.member?(node_ids, e.from_node_id) or
          not MapSet.member?(node_ids, e.to_node_id)
      end)

    now = DateTime.utc_now()

    stale =
      Enum.count(nodes, fn n ->
        DateTime.diff(now, n.updated_at, :day) > 7
      end)

    %{
      total_nodes: stats.nodes,
      total_edges: stats.edges,
      by_type: by_type,
      active_goals: length(active_goals),
      orphan_nodes: orphans,
      dangling_outcomes: dangling_outcomes,
      broken_edges: broken_edges,
      stale_nodes: stale,
      health: health_score(orphans, dangling_outcomes, broken_edges)
    }
  end

  defp health_score(0, 0, 0), do: "healthy"

  defp health_score(orphans, dangling, broken) when orphans + dangling + broken > 5,
    do: "needs attention"

  defp health_score(_, _, _), do: "minor issues"

  defp print_pulse(pulse) do
    IO.puts("Graph Pulse")
    IO.puts(String.duplicate("=", 40))
    IO.puts("  Status:           #{pulse.health}")
    IO.puts("  Total nodes:      #{pulse.total_nodes}")
    IO.puts("  Total edges:      #{pulse.total_edges}")
    IO.puts("  Active goals:     #{pulse.active_goals}")
    IO.puts("")
    IO.puts("  By type:")

    pulse.by_type
    |> Enum.sort_by(fn {_t, c} -> -c end)
    |> Enum.each(fn {type, count} ->
      IO.puts("    #{String.pad_trailing(to_string(type), 13)} #{count}")
    end)

    IO.puts("")
    IO.puts("  Issues:")
    IO.puts("    Orphan nodes:      #{pulse.orphan_nodes}")
    IO.puts("    Dangling outcomes: #{pulse.dangling_outcomes}")
    IO.puts("    Broken edges:      #{pulse.broken_edges}")
    IO.puts("    Stale nodes (7d):  #{pulse.stale_nodes}")
  end
end
