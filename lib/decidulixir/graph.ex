defmodule Decidulixir.Graph do
  @moduledoc """
  Public API for decision graph operations.

  This is the Phoenix Context module — the single entry point for all
  graph CRUD, queries, and mutations. CLI and Web layers call ONLY
  this module; they never touch Ecto directly.

  Replaces the Rust `Database` god-object (3,564 LOC, 124 functions)
  with a focused API backed by composable query modules.
  """

  import Ecto.Query

  alias Decidulixir.Graph.ConversationNodeSet
  alias Decidulixir.Graph.GraphDocument
  alias Decidulixir.Graph.GraphEdge
  alias Decidulixir.Graph.Metadata
  alias Decidulixir.Graph.Node
  alias Decidulixir.Graph.NodeConversationNodeSet
  alias Decidulixir.Graph.Queries
  alias Decidulixir.Repo

  # ── Node CRUD ─────────────────────────────────────────────

  @doc "Creates a new decision graph node."
  @spec create_node(map()) :: {:ok, Node.t()} | {:error, Ecto.Changeset.t()}
  def create_node(attrs) do
    %Node{}
    |> Node.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Gets a node by ID. Returns `nil` if not found."
  @spec get_node(integer()) :: Node.t() | nil
  def get_node(id), do: Repo.get(Node, id)

  @doc "Gets a node by ID. Raises if not found."
  @spec get_node!(integer()) :: Node.t()
  def get_node!(id), do: Repo.get!(Node, id)

  @doc "Gets a node by its UUID change_id. Used by Loom adapter."
  @spec get_node_by_change_id(String.t()) :: Node.t() | nil
  def get_node_by_change_id(change_id) do
    Repo.get_by(Node, change_id: change_id)
  end

  @doc "Updates a node with the given attrs."
  @spec update_node(Node.t(), map()) :: {:ok, Node.t()} | {:error, Ecto.Changeset.t()}
  def update_node(%Node{} = node, attrs) do
    node
    |> Node.update_changeset(attrs)
    |> Repo.update()
  end

  @doc "Updates a node's status."
  @spec update_node_status(integer(), atom()) :: {:ok, Node.t()} | {:error, Ecto.Changeset.t()}
  def update_node_status(id, status) do
    get_node!(id)
    |> update_node(%{status: status})
  end

  @doc "Updates a node's prompt in metadata."
  @spec update_node_prompt(integer(), String.t()) ::
          {:ok, Node.t()} | {:error, Ecto.Changeset.t()}
  def update_node_prompt(id, prompt) do
    node = get_node!(id)
    new_metadata = Metadata.set_prompt(node.metadata, prompt)
    update_node(node, %{metadata: new_metadata})
  end

  @doc """
  Deletes a node and its associated edges.

  With `dry_run: true`, returns what would be deleted without actually deleting.
  """
  @spec delete_node(integer(), keyword()) ::
          {:ok, %{node: Node.t(), edges_removed: integer()}}
          | {:error, :not_found}
  def delete_node(id, opts \\ []) do
    case get_node(id) do
      nil ->
        {:error, :not_found}

      node ->
        edge_count =
          GraphEdge
          |> Queries.edges_involving(id)
          |> Repo.aggregate(:count, :id)

        if Keyword.get(opts, :dry_run, false) do
          {:ok, %{node: node, edges_removed: edge_count}}
        else
          GraphEdge
          |> Queries.edges_involving(id)
          |> Repo.delete_all()

          Repo.delete(node)
          {:ok, %{node: node, edges_removed: edge_count}}
        end
    end
  end

  # ── Edge CRUD ─────────────────────────────────────────────

  @doc "Creates an edge between two nodes."
  @spec create_edge(integer(), integer(), map()) ::
          {:ok, GraphEdge.t()} | {:error, Ecto.Changeset.t()}
  def create_edge(from_id, to_id, attrs \\ %{}) do
    attrs = Map.merge(attrs, %{from_node_id: from_id, to_node_id: to_id})

    %GraphEdge{}
    |> GraphEdge.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Deletes an edge between two nodes."
  @spec delete_edge(integer(), integer()) :: {:ok, integer()}
  def delete_edge(from_id, to_id) do
    {count, _} =
      GraphEdge
      |> where([e], e.from_node_id == ^from_id and e.to_node_id == ^to_id)
      |> Repo.delete_all()

    {:ok, count}
  end

  @doc "Gets edges from a node."
  @spec edges_from(integer()) :: [GraphEdge.t()]
  def edges_from(node_id) do
    GraphEdge
    |> Queries.edges_from(node_id)
    |> Repo.all()
  end

  @doc "Gets edges to a node."
  @spec edges_to(integer()) :: [GraphEdge.t()]
  def edges_to(node_id) do
    GraphEdge
    |> Queries.edges_to(node_id)
    |> Repo.all()
  end

  # ── Queries ───────────────────────────────────────────────

  @doc "Lists all nodes, optionally filtered."
  @spec list_nodes(keyword()) :: [Node.t()]
  def list_nodes(filters \\ []) do
    filters
    |> Enum.reduce(Node, fn
      {:node_type, type}, q -> Queries.by_type(q, type)
      {:status, status}, q -> Queries.by_status(q, status)
      {:branch, branch}, q -> Queries.by_branch(q, branch)
      {:search, term}, q -> Queries.search_title_or_description(q, term)
      {:limit, limit}, q -> Queries.recent(q, limit)
      _, q -> q
    end)
    |> order_by([n], asc: n.id)
    |> Repo.all()
  end

  @doc "Lists all edges, optionally filtered."
  @spec list_edges(keyword()) :: [GraphEdge.t()]
  def list_edges(filters \\ []) do
    filters
    |> Enum.reduce(GraphEdge, fn
      {:edge_type, type}, q -> Queries.by_edge_type(q, type)
      {:from_node_id, id}, q -> Queries.edges_from(q, id)
      {:to_node_id, id}, q -> Queries.edges_to(q, id)
      _, q -> q
    end)
    |> Repo.all()
  end

  @doc "Returns the full graph: all nodes and edges."
  @spec get_graph(keyword()) :: %{nodes: [Node.t()], edges: [GraphEdge.t()]}
  def get_graph(filters \\ []) do
    %{
      nodes: list_nodes(filters),
      edges: list_edges()
    }
  end

  # ── Convenience ───────────────────────────────────────────

  @doc "Returns all active goal nodes."
  @spec active_goals() :: [Node.t()]
  def active_goals do
    list_nodes(node_type: :goal, status: :active)
  end

  @doc "Returns recent decisions and options."
  @spec recent_decisions(integer()) :: [Node.t()]
  def recent_decisions(limit \\ 10) do
    Node
    |> where([n], n.node_type in [:decision, :option])
    |> Queries.recent(limit)
    |> Repo.all()
  end

  @doc """
  Marks a node as superseded and creates a supersedes edge to the new node.

  Uses `Ecto.Multi` for atomicity.
  """
  @spec supersede(integer(), integer(), String.t()) ::
          {:ok, %{status: Node.t(), edge: GraphEdge.t()}} | {:error, atom(), term(), map()}
  # Ecto.Multi uses opaque MapSet internally; dialyzer flags the pipe chain
  @dialyzer {:nowarn_function, supersede: 3}
  def supersede(old_id, new_id, rationale) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:old_node, fn _repo, _changes ->
      case get_node(old_id) do
        nil -> {:error, :not_found}
        node -> {:ok, node}
      end
    end)
    |> Ecto.Multi.run(:status, fn _repo, %{old_node: node} ->
      update_node(node, %{status: :superseded})
    end)
    |> Ecto.Multi.run(:edge, fn _repo, _changes ->
      create_edge(old_id, new_id, %{edge_type: :leads_to, rationale: rationale})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, results} -> {:ok, %{status: results.status, edge: results.edge}}
      {:error, step, reason, _} -> {:error, step, reason, %{}}
    end
  end

  # ── Documents ─────────────────────────────────────────────

  @doc "Lists documents for a node."
  @spec list_documents(integer()) :: [GraphDocument.t()]
  def list_documents(node_id) do
    GraphDocument
    |> where([d], d.node_id == ^node_id and is_nil(d.detached_at))
    |> Repo.all()
  end

  # ── Conversation Node Sets ────────────────────────────────

  @doc "Lists nodes in a conversation set."
  @spec nodes_in_conversation_set(integer()) :: [Node.t()]
  def nodes_in_conversation_set(set_id) do
    Node
    |> join(:inner, [n], j in NodeConversationNodeSet,
      on: j.node_id == n.id and j.conversation_node_set_id == ^set_id
    )
    |> order_by([n], asc: n.inserted_at)
    |> Repo.all()
  end

  @doc "Creates a conversation node set."
  @spec create_conversation_set(map()) ::
          {:ok, ConversationNodeSet.t()} | {:error, Ecto.Changeset.t()}
  def create_conversation_set(attrs) do
    %ConversationNodeSet{}
    |> ConversationNodeSet.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Adds a node to a conversation set."
  @spec add_node_to_conversation_set(integer(), integer()) ::
          {:ok, NodeConversationNodeSet.t()} | {:error, Ecto.Changeset.t()}
  def add_node_to_conversation_set(node_id, set_id) do
    %NodeConversationNodeSet{}
    |> NodeConversationNodeSet.changeset(%{
      node_id: node_id,
      conversation_node_set_id: set_id,
      added_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert()
  end

  # ── Stats ─────────────────────────────────────────────────

  @doc "Returns node count by type."
  @spec node_counts_by_type() :: %{atom() => integer()}
  def node_counts_by_type do
    Node
    |> group_by([n], n.node_type)
    |> select([n], {n.node_type, count(n.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc "Returns total node and edge counts."
  @spec graph_stats() :: %{nodes: integer(), edges: integer()}
  def graph_stats do
    %{
      nodes: Repo.aggregate(Node, :count, :id),
      edges: Repo.aggregate(GraphEdge, :count, :id)
    }
  end
end
