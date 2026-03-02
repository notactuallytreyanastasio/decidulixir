defmodule Decidulixir.Adapters.DecisionGraph.Native do
  @moduledoc """
  Native adapter — wraps Decidulixir.Graph context to implement
  the DecisionGraph behaviour. This is the default backend.
  """

  @behaviour Decidulixir.Adapters.DecisionGraph

  alias Decidulixir.Graph
  alias Decidulixir.Graph.Traversal

  # ── Node CRUD ──────────────────────────────────────────

  @impl true
  def create_node(attrs) do
    case Graph.create_node(attrs) do
      {:ok, node} -> {:ok, serialize_node(node)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def get_node(id) when is_integer(id) do
    case Graph.get_node(id) do
      nil -> {:error, :not_found}
      node -> {:ok, serialize_node(node)}
    end
  end

  def get_node(uuid) when is_binary(uuid) do
    case Graph.get_node_by_change_id(uuid) do
      nil -> {:error, :not_found}
      node -> {:ok, serialize_node(node)}
    end
  end

  @impl true
  def update_node(id, attrs) when is_integer(id) do
    case Graph.get_node(id) do
      nil -> {:error, :not_found}
      node -> do_update(node, attrs)
    end
  end

  def update_node(uuid, attrs) when is_binary(uuid) do
    case Graph.get_node_by_change_id(uuid) do
      nil -> {:error, :not_found}
      node -> do_update(node, attrs)
    end
  end

  defp do_update(node, attrs) do
    case Graph.update_node(node, attrs) do
      {:ok, updated} -> {:ok, serialize_node(updated)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def delete_node(id) when is_integer(id) do
    case Graph.delete_node(id) do
      {:ok, result} -> {:ok, serialize_node(result.node)}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def delete_node(uuid) when is_binary(uuid) do
    case Graph.get_node_by_change_id(uuid) do
      nil -> {:error, :not_found}
      node -> delete_node(node.id)
    end
  end

  @impl true
  def list_nodes(filters \\ []) do
    {:ok, filters |> Graph.list_nodes() |> Enum.map(&serialize_node/1)}
  end

  # ── Edge CRUD ──────────────────────────────────────────

  @impl true
  def create_edge(from_id, to_id, edge_type, opts \\ []) do
    attrs = %{edge_type: edge_type}
    attrs = if opts[:rationale], do: Map.put(attrs, :rationale, opts[:rationale]), else: attrs

    case Graph.create_edge(from_id, to_id, attrs) do
      {:ok, edge} -> {:ok, serialize_edge(edge)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def list_edges(filters \\ []) do
    {:ok, filters |> Graph.list_edges() |> Enum.map(&serialize_edge/1)}
  end

  # ── Convenience ────────────────────────────────────────

  @impl true
  def active_goals do
    {:ok, Graph.active_goals() |> Enum.map(&serialize_node/1)}
  end

  @impl true
  def recent_decisions(limit \\ 10) do
    {:ok, Graph.recent_decisions(limit) |> Enum.map(&serialize_node/1)}
  end

  @impl true
  def supersede(old_id, new_id, rationale) do
    case Graph.supersede(old_id, new_id, rationale) do
      {:ok, result} -> {:ok, serialize_edge(result.edge)}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  # ── Analysis ───────────────────────────────────────────

  @impl true
  def build_context(session_id, opts \\ []) do
    max_tokens = Keyword.get(opts, :max_tokens, 1024)

    sections = []

    # Active goals
    goals = Graph.active_goals()

    sections =
      if goals != [] do
        goal_text =
          Enum.map_join(goals, "\n", fn g -> "- #{g.title} (#{g.status})" end)

        ["## Active Goals\n#{goal_text}" | sections]
      else
        sections
      end

    # Recent decisions
    decisions = Graph.recent_decisions(5)

    sections =
      if decisions != [] do
        dec_text =
          Enum.map_join(decisions, "\n", fn d -> "- #{d.title} (#{d.node_type})" end)

        ["## Recent Decisions\n#{dec_text}" | sections]
      else
        sections
      end

    # Session context
    sections = append_session_context(sections, session_id)

    context = sections |> Enum.reverse() |> Enum.join("\n\n")
    context = String.slice(context, 0, max_tokens)
    {:ok, context}
  end

  @impl true
  def pulse(opts \\ []) do
    confidence_threshold = Keyword.get(opts, :confidence_threshold, 50)
    stale_days = Keyword.get(opts, :stale_days, 7)

    goals = Graph.active_goals()
    decisions = Graph.recent_decisions(20)
    all_nodes = Graph.list_nodes()
    all_edges = Graph.list_edges()
    stale_cutoff = DateTime.add(DateTime.utc_now(), -stale_days * 86_400, :second)

    connected_ids =
      all_edges
      |> Enum.flat_map(fn e -> [e.from_node_id, e.to_node_id] end)
      |> MapSet.new()

    orphans =
      all_nodes
      |> Enum.reject(fn n -> n.node_type == :goal or MapSet.member?(connected_ids, n.id) end)

    low_confidence =
      all_nodes
      |> Enum.filter(fn n ->
        c = get_in(n.metadata || %{}, ["confidence"])
        c && c < confidence_threshold
      end)

    stale =
      all_nodes
      |> Enum.filter(fn n ->
        n.status == :active and DateTime.compare(n.updated_at, stale_cutoff) == :lt
      end)

    coverage_gaps = find_coverage_gaps(goals, all_edges)

    report = %{
      active_goals: Enum.map(goals, &serialize_node/1),
      recent_decisions: Enum.map(decisions, &serialize_node/1),
      coverage_gaps: coverage_gaps,
      low_confidence: Enum.map(low_confidence, &serialize_node/1),
      stale_nodes: Enum.map(stale, &serialize_node/1),
      orphan_nodes: Enum.map(orphans, &serialize_node/1),
      summary: %{
        total_nodes: length(all_nodes),
        total_edges: length(all_edges),
        active_goals: length(goals),
        orphan_count: length(orphans),
        stale_count: length(stale),
        low_confidence_count: length(low_confidence)
      }
    }

    {:ok, report}
  end

  @impl true
  def narrative_for_goal(goal_id) when is_integer(goal_id) do
    descendants = Traversal.bfs_descendants(goal_id)
    {:ok, descendants |> Enum.sort_by(& &1.inserted_at) |> Enum.map(&serialize_node/1)}
  end

  def narrative_for_goal(uuid) when is_binary(uuid) do
    case Graph.get_node_by_change_id(uuid) do
      nil -> {:ok, []}
      node -> narrative_for_goal(node.id)
    end
  end

  @impl true
  def format_timeline(nodes) do
    Enum.map_join(nodes, "\n", fn n ->
      timestamp = n[:inserted_at] || n["inserted_at"] || "?"
      type = n[:node_type] || n["node_type"] || "?"
      title = n[:title] || n["title"] || "?"
      "  #{timestamp}  [#{type}]  #{title}"
    end)
  end

  # ── Serialization ──────────────────────────────────────

  defp serialize_node(node) do
    %{
      id: node.id,
      change_id: node.change_id,
      node_type: node.node_type,
      title: node.title,
      description: node.description,
      status: node.status,
      metadata: node.metadata,
      inserted_at: node.inserted_at,
      updated_at: node.updated_at
    }
  end

  defp serialize_edge(edge) do
    %{
      id: edge.id,
      from_node_id: edge.from_node_id,
      to_node_id: edge.to_node_id,
      edge_type: edge.edge_type,
      weight: edge.weight,
      rationale: edge.rationale,
      inserted_at: edge.inserted_at
    }
  end

  defp append_session_context(sections, nil), do: sections

  defp append_session_context(sections, session_id) do
    nodes = Graph.nodes_in_conversation_set(session_id)

    if nodes != [] do
      session_text = Enum.map_join(nodes, "\n", fn n -> "- [#{n.node_type}] #{n.title}" end)
      ["## Session Context\n#{session_text}" | sections]
    else
      sections
    end
  end

  defp find_coverage_gaps(goals, all_edges) do
    from_ids = MapSet.new(all_edges, & &1.from_node_id)

    goals
    |> Enum.reject(fn g -> MapSet.member?(from_ids, g.id) end)
    |> Enum.map(fn g -> %{node_id: g.id, title: g.title, gap: "no outgoing edges"} end)
  end
end
