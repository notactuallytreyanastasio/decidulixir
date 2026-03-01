defmodule Decidulixir.Adapters.DecisionGraph do
  @moduledoc """
  Behaviour for decision graph backends.

  Decidulixir implements this natively via `Native`; Loom can use
  the `Loom` adapter which translates between Loom's UUID-based
  API and Decidulixir's integer-based internals.
  """

  @type node_id :: integer() | binary()
  @type node_result :: map()
  @type edge_result :: map()
  @type filter :: {atom(), term()}

  # ── Node CRUD ──────────────────────────────────────────

  @doc "Creates a new decision graph node."
  @callback create_node(attrs :: map()) :: {:ok, node_result()} | {:error, term()}

  @doc "Gets a node by ID."
  @callback get_node(id :: node_id()) :: {:ok, node_result()} | {:error, :not_found}

  @doc "Updates a node."
  @callback update_node(id :: node_id(), attrs :: map()) :: {:ok, node_result()} | {:error, term()}

  @doc "Deletes a node."
  @callback delete_node(id :: node_id()) :: {:ok, node_result()} | {:error, :not_found}

  @doc "Lists nodes with optional filters."
  @callback list_nodes(filters :: [filter()]) :: {:ok, [node_result()]}

  # ── Edge CRUD ──────────────────────────────────────────

  @doc "Creates an edge between two nodes."
  @callback create_edge(from_id :: node_id(), to_id :: node_id(), edge_type :: atom(), opts :: keyword()) ::
              {:ok, edge_result()} | {:error, term()}

  @doc "Lists edges with optional filters."
  @callback list_edges(filters :: [filter()]) :: {:ok, [edge_result()]}

  # ── Convenience ────────────────────────────────────────

  @doc "Returns active goal nodes."
  @callback active_goals() :: {:ok, [node_result()]}

  @doc "Returns recent decisions."
  @callback recent_decisions(limit :: integer()) :: {:ok, [node_result()]}

  @doc "Marks old node as superseded and links to new node."
  @callback supersede(old_id :: node_id(), new_id :: node_id(), rationale :: String.t()) ::
              {:ok, edge_result()} | {:error, term()}

  # ── Analysis ───────────────────────────────────────────

  @doc "Builds a context string for LLM injection."
  @callback build_context(session_id :: binary() | nil, opts :: keyword()) :: {:ok, String.t()}

  @doc "Generates a pulse report (health/coverage analysis)."
  @callback pulse(opts :: keyword()) :: {:ok, map()}

  @doc "Returns narrative nodes for a goal (BFS descendants)."
  @callback narrative_for_goal(goal_id :: node_id()) :: {:ok, [node_result()]}

  @doc "Formats a list of nodes as a human-readable timeline."
  @callback format_timeline(nodes :: [node_result()]) :: String.t()

  @doc "Returns the configured adapter module."
  @spec adapter() :: module()
  def adapter do
    Application.get_env(:decidulixir, :decision_graph_adapter, __MODULE__.Native)
  end
end
