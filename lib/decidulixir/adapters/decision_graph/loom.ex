defmodule Decidulixir.Adapters.DecisionGraph.Loom do
  @moduledoc """
  Loom-compatible adapter that translates between Loom's UUID-based
  API and Decidulixir's integer-based internals.

  Key translations:
  - IDs: Loom uses binary UUIDs; Decidulixir uses integer serial + UUID change_id
  - Confidence: Loom stores on node directly; Decidulixir stores in metadata JSON
  - Agent name: Loom stores on node directly; Decidulixir stores in metadata JSON
  - Sessions: Loom uses session_id FK; Decidulixir uses join table
  - Edge types: Loom has :supersedes/:supports; added to Decidulixir's schema
  - Statuses: Loom has 3; Decidulixir has 6 (superset, no translation needed)
  """

  @behaviour Decidulixir.Adapters.DecisionGraph

  alias Decidulixir.Graph
  alias Decidulixir.Graph.Metadata
  alias Decidulixir.Graph.Traversal

  # ── Node CRUD ──────────────────────────────────────────

  @impl true
  def create_node(attrs) do
    {loom_fields, core_attrs} = extract_loom_fields(attrs)
    core_attrs = merge_loom_metadata(core_attrs, loom_fields)

    case Graph.create_node(core_attrs) do
      {:ok, node} ->
        maybe_add_to_session(node, loom_fields[:session_id])
        {:ok, to_loom_node(node)}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @impl true
  def get_node(uuid) when is_binary(uuid) do
    case Graph.get_node_by_change_id(uuid) do
      nil -> {:error, :not_found}
      node -> {:ok, to_loom_node(node)}
    end
  end

  def get_node(id) when is_integer(id) do
    case Graph.get_node(id) do
      nil -> {:error, :not_found}
      node -> {:ok, to_loom_node(node)}
    end
  end

  @impl true
  def update_node(uuid, attrs) when is_binary(uuid) do
    case Graph.get_node_by_change_id(uuid) do
      nil ->
        {:error, :not_found}

      node ->
        {loom_fields, core_attrs} = extract_loom_fields(attrs)
        core_attrs = merge_loom_metadata_for_update(node, core_attrs, loom_fields)

        case Graph.update_node(node, core_attrs) do
          {:ok, updated} -> {:ok, to_loom_node(updated)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  def update_node(id, attrs) when is_integer(id) do
    case Graph.get_node(id) do
      nil -> {:error, :not_found}
      node -> update_node(node.change_id, attrs)
    end
  end

  @impl true
  def delete_node(uuid) when is_binary(uuid) do
    case Graph.get_node_by_change_id(uuid) do
      nil ->
        {:error, :not_found}

      node ->
        case Graph.delete_node(node.id) do
          {:ok, result} -> {:ok, to_loom_node(result.node)}
          {:error, :not_found} -> {:error, :not_found}
        end
    end
  end

  def delete_node(id) when is_integer(id) do
    case Graph.get_node(id) do
      nil -> {:error, :not_found}
      node -> delete_node(node.change_id)
    end
  end

  @impl true
  def list_nodes(filters \\ []) do
    {:ok, filters |> Graph.list_nodes() |> Enum.map(&to_loom_node/1)}
  end

  # ── Edge CRUD ──────────────────────────────────────────

  @impl true
  def create_edge(from_uuid, to_uuid, edge_type, opts \\ []) do
    with {:ok, from_node} <- resolve_node(from_uuid),
         {:ok, to_node} <- resolve_node(to_uuid) do
      attrs = %{edge_type: edge_type}
      attrs = if opts[:rationale], do: Map.put(attrs, :rationale, opts[:rationale]), else: attrs

      case Graph.create_edge(from_node.id, to_node.id, attrs) do
        {:ok, edge} -> {:ok, to_loom_edge(edge)}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  @impl true
  def list_edges(filters \\ []) do
    {:ok, filters |> Graph.list_edges() |> Enum.map(&to_loom_edge/1)}
  end

  # ── Convenience ────────────────────────────────────────

  @impl true
  def active_goals do
    {:ok, Graph.active_goals() |> Enum.map(&to_loom_node/1)}
  end

  @impl true
  def recent_decisions(limit \\ 10) do
    {:ok, Graph.recent_decisions(limit) |> Enum.map(&to_loom_node/1)}
  end

  @impl true
  def supersede(old_uuid, new_uuid, rationale) do
    with {:ok, old_node} <- resolve_node(old_uuid),
         {:ok, new_node} <- resolve_node(new_uuid) do
      case Graph.supersede(old_node.id, new_node.id, rationale) do
        {:ok, result} -> {:ok, to_loom_edge(result.edge)}
        {:error, _step, reason, _} -> {:error, reason}
      end
    end
  end

  # ── Analysis ───────────────────────────────────────────

  @impl true
  def build_context(session_id, opts \\ []) do
    # Delegate to native — analysis doesn't need ID translation
    Decidulixir.Adapters.DecisionGraph.Native.build_context(session_id, opts)
  end

  @impl true
  def pulse(opts \\ []) do
    # Get native pulse, then translate node IDs to UUIDs
    {:ok, report} = Decidulixir.Adapters.DecisionGraph.Native.pulse(opts)

    {:ok,
     %{
       report
       | active_goals: Enum.map(report.active_goals, &remap_id/1),
         recent_decisions: Enum.map(report.recent_decisions, &remap_id/1),
         low_confidence: Enum.map(report.low_confidence, &remap_id/1),
         stale_nodes: Enum.map(report.stale_nodes, &remap_id/1),
         orphan_nodes: Enum.map(report.orphan_nodes, &remap_id/1)
     }}
  end

  @impl true
  def narrative_for_goal(uuid) when is_binary(uuid) do
    case Graph.get_node_by_change_id(uuid) do
      nil ->
        {:ok, []}

      node ->
        descendants = Traversal.bfs_descendants(node.id)
        {:ok, descendants |> Enum.sort_by(& &1.inserted_at) |> Enum.map(&to_loom_node/1)}
    end
  end

  def narrative_for_goal(id) when is_integer(id) do
    case Graph.get_node(id) do
      nil -> {:ok, []}
      node -> narrative_for_goal(node.change_id)
    end
  end

  @impl true
  def format_timeline(nodes) do
    Decidulixir.Adapters.DecisionGraph.Native.format_timeline(nodes)
  end

  # ── Translation helpers ────────────────────────────────

  @loom_only_fields [:confidence, :agent_name, :session_id]

  defp extract_loom_fields(attrs) do
    loom = Map.take(attrs, @loom_only_fields)
    core = Map.drop(attrs, @loom_only_fields)
    {loom, core}
  end

  defp merge_loom_metadata(core_attrs, loom_fields) do
    meta = Map.get(core_attrs, :metadata, %{})

    meta =
      loom_fields
      |> Enum.reduce(meta, fn
        {:confidence, v}, acc when not is_nil(v) -> Metadata.set_confidence(acc, v)
        {:agent_name, v}, acc when not is_nil(v) -> Map.put(acc || %{}, "agent_name", v)
        _, acc -> acc
      end)

    Map.put(core_attrs, :metadata, meta)
  end

  defp merge_loom_metadata_for_update(existing_node, core_attrs, loom_fields) do
    meta = Map.get(core_attrs, :metadata, existing_node.metadata || %{})

    meta =
      loom_fields
      |> Enum.reduce(meta, fn
        {:confidence, v}, acc when not is_nil(v) -> Metadata.set_confidence(acc, v)
        {:agent_name, v}, acc when not is_nil(v) -> Map.put(acc || %{}, "agent_name", v)
        _, acc -> acc
      end)

    Map.put(core_attrs, :metadata, meta)
  end

  defp maybe_add_to_session(_node, nil), do: :ok

  defp maybe_add_to_session(node, session_id) when is_integer(session_id) do
    Graph.add_node_to_conversation_set(node.id, session_id)
  end

  defp maybe_add_to_session(_node, _session_id), do: :ok

  defp resolve_node(uuid) when is_binary(uuid) do
    case Graph.get_node_by_change_id(uuid) do
      nil -> {:error, :not_found}
      node -> {:ok, node}
    end
  end

  defp resolve_node(id) when is_integer(id) do
    case Graph.get_node(id) do
      nil -> {:error, :not_found}
      node -> {:ok, node}
    end
  end

  defp to_loom_node(node) do
    meta = node.metadata || %{}

    %{
      id: node.change_id,
      change_id: node.change_id,
      node_type: node.node_type,
      title: node.title,
      description: node.description,
      status: node.status,
      confidence: meta["confidence"],
      agent_name: meta["agent_name"],
      metadata: Map.drop(meta, ["confidence", "agent_name"]),
      session_id: nil,
      inserted_at: node.inserted_at,
      updated_at: node.updated_at
    }
  end

  defp to_loom_edge(edge) do
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

  defp remap_id(%{change_id: change_id} = node) do
    %{node | id: change_id}
  end

  defp remap_id(node), do: node
end
