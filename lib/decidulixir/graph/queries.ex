defmodule Decidulixir.Graph.Queries do
  @moduledoc """
  Composable Ecto query builders for decision graph nodes and edges.

  All functions accept and return `Ecto.Queryable` so they can be piped:

      Node
      |> Queries.by_type(:goal)
      |> Queries.by_status(:active)
      |> Queries.recent(10)
      |> Repo.all()
  """

  import Ecto.Query

  alias Decidulixir.Graph.GraphEdge
  alias Decidulixir.Graph.Node

  # ── Node queries ──────────────────────────────────────────

  @spec by_type(Ecto.Queryable.t(), atom()) :: Ecto.Query.t()
  def by_type(query \\ Node, node_type) do
    where(query, [n], n.node_type == ^node_type)
  end

  @spec by_status(Ecto.Queryable.t(), atom()) :: Ecto.Query.t()
  def by_status(query \\ Node, status) do
    where(query, [n], n.status == ^status)
  end

  @spec by_branch(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def by_branch(query \\ Node, branch) do
    where(query, [n], fragment("? ->> 'branch' = ?", n.metadata, ^branch))
  end

  @spec recent(Ecto.Queryable.t(), non_neg_integer()) :: Ecto.Query.t()
  def recent(query \\ Node, limit) do
    query
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
  end

  @spec with_metadata_key(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def with_metadata_key(query \\ Node, key) do
    where(query, [n], fragment("? \\? ?", n.metadata, ^key))
  end

  @spec search_title(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def search_title(query \\ Node, term) do
    pattern = "%#{term}%"
    where(query, [n], ilike(n.title, ^pattern))
  end

  @spec search_title_or_description(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def search_title_or_description(query \\ Node, term) do
    pattern = "%#{term}%"
    where(query, [n], ilike(n.title, ^pattern) or ilike(n.description, ^pattern))
  end

  # ── Edge queries ──────────────────────────────────────────

  @spec by_edge_type(Ecto.Queryable.t(), atom()) :: Ecto.Query.t()
  def by_edge_type(query \\ GraphEdge, edge_type) do
    where(query, [e], e.edge_type == ^edge_type)
  end

  @spec edges_from(Ecto.Queryable.t(), integer()) :: Ecto.Query.t()
  def edges_from(query \\ GraphEdge, node_id) do
    where(query, [e], e.from_node_id == ^node_id)
  end

  @spec edges_to(Ecto.Queryable.t(), integer()) :: Ecto.Query.t()
  def edges_to(query \\ GraphEdge, node_id) do
    where(query, [e], e.to_node_id == ^node_id)
  end

  @spec edges_involving(Ecto.Queryable.t(), integer()) :: Ecto.Query.t()
  def edges_involving(query \\ GraphEdge, node_id) do
    where(query, [e], e.from_node_id == ^node_id or e.to_node_id == ^node_id)
  end
end
