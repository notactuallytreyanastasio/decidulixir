defmodule Decidulixir.Archaeology.Operations.Pivot do
  @moduledoc """
  Atomic pivot chain creation.

  A pivot chain captures when a design approach is abandoned and replaced:

      [Old Decision] → [Observation: why it failed] → [REVISIT] → [New Decision]

  All 7 steps happen in a single `Ecto.Multi` transaction.
  """

  alias Decidulixir.Graph
  alias Decidulixir.Graph.{GraphEdge, Node}
  alias Decidulixir.Repo

  @type pivot_result :: %{
          observation: Node.t(),
          revisit: Node.t(),
          new_decision: Node.t(),
          edges: [GraphEdge.t()]
        }

  @doc """
  Creates a complete pivot chain atomically.

  ## Steps (all in one transaction)
  1. Create observation node (why the old approach failed)
  2. Link from_id → observation
  3. Create revisit node
  4. Link observation → revisit
  5. Create new decision node
  6. Link revisit → new decision
  7. Mark old node as superseded
  """
  @spec create_pivot(integer(), String.t(), String.t(), keyword()) ::
          {:ok, pivot_result()} | {:error, atom(), term(), map()}
  # Ecto.Multi uses opaque MapSet internally; dialyzer flags the pipe chain
  @dialyzer {:nowarn_function, create_pivot: 4}
  def create_pivot(from_id, observation_text, new_approach, opts \\ []) do
    confidence = Keyword.get(opts, :confidence, 70)
    metadata = Keyword.get(opts, :metadata, %{})

    Ecto.Multi.new()
    |> Ecto.Multi.run(:from_node, fn _repo, _changes ->
      case Graph.get_node(from_id) do
        nil -> {:error, :not_found}
        node -> {:ok, node}
      end
    end)
    |> Ecto.Multi.run(:observation, fn _repo, _changes ->
      Graph.create_node(%{
        node_type: :observation,
        title: observation_text,
        metadata: Map.merge(metadata, %{"confidence" => confidence})
      })
    end)
    |> Ecto.Multi.run(:edge_from_to_obs, fn _repo, %{observation: obs} ->
      Graph.create_edge(from_id, obs.id, %{
        edge_type: :leads_to,
        rationale: "observation from #{from_id}"
      })
    end)
    |> Ecto.Multi.run(:revisit, fn _repo, _changes ->
      Graph.create_node(%{
        node_type: :revisit,
        title: "Reconsidering: #{observation_text}",
        metadata: %{"confidence" => confidence}
      })
    end)
    |> Ecto.Multi.run(:edge_obs_to_revisit, fn _repo, %{observation: obs, revisit: rev} ->
      Graph.create_edge(obs.id, rev.id, %{
        edge_type: :leads_to,
        rationale: "forced rethinking"
      })
    end)
    |> Ecto.Multi.run(:new_decision, fn _repo, _changes ->
      Graph.create_node(%{
        node_type: :decision,
        title: new_approach,
        metadata: Map.merge(metadata, %{"confidence" => confidence})
      })
    end)
    |> Ecto.Multi.run(:edge_revisit_to_new, fn _repo, %{revisit: rev, new_decision: dec} ->
      Graph.create_edge(rev.id, dec.id, %{
        edge_type: :leads_to,
        rationale: "new approach"
      })
    end)
    |> Ecto.Multi.run(:supersede_old, fn _repo, %{from_node: node} ->
      Graph.update_node(node, %{status: :superseded})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, results} ->
        {:ok,
         %{
           observation: results.observation,
           revisit: results.revisit,
           new_decision: results.new_decision,
           edges: [
             results.edge_from_to_obs,
             results.edge_obs_to_revisit,
             results.edge_revisit_to_new
           ]
         }}

      {:error, step, reason, changes} ->
        {:error, step, reason, changes}
    end
  end

  @doc """
  Finds all pivot chains in the graph.

  A pivot chain is identified by finding revisit nodes and tracing their
  connections: incoming observations and outgoing new decisions.
  """
  @spec find_pivots() :: [pivot_result()]
  def find_pivots do
    import Ecto.Query

    revisit_nodes =
      Node
      |> where([n], n.node_type == :revisit)
      |> order_by([n], asc: n.inserted_at)
      |> Repo.all()

    Enum.map(revisit_nodes, fn revisit ->
      # Find incoming observations
      observations =
        GraphEdge
        |> where([e], e.to_node_id == ^revisit.id)
        |> join(:inner, [e], n in Node, on: n.id == e.from_node_id)
        |> select([_e, n], n)
        |> Repo.all()

      # Find outgoing new decisions
      new_decisions =
        GraphEdge
        |> where([e], e.from_node_id == ^revisit.id)
        |> join(:inner, [e], n in Node, on: n.id == e.to_node_id)
        |> select([_e, n], n)
        |> Repo.all()

      %{
        revisit: revisit,
        observations: observations,
        new_decisions: new_decisions
      }
    end)
  end
end
