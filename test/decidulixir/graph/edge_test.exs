defmodule Decidulixir.Graph.GraphEdgeTest do
  use Decidulixir.DataCase, async: true

  alias Decidulixir.Graph.{Node, GraphEdge}
  alias Decidulixir.Repo

  defp create_node!(attrs \\ %{}) do
    %Node{}
    |> Node.changeset(Map.merge(%{node_type: :goal, title: "Test node"}, attrs))
    |> Repo.insert!()
  end

  describe "changeset/2" do
    test "valid with required fields" do
      node1 = create_node!(%{title: "From"})
      node2 = create_node!(%{title: "To"})

      changeset = GraphEdge.changeset(%GraphEdge{}, %{from_node_id: node1.id, to_node_id: node2.id})
      assert changeset.valid?
    end

    test "defaults edge_type to leads_to" do
      node1 = create_node!()
      node2 = create_node!(%{title: "Other"})

      changeset = GraphEdge.changeset(%GraphEdge{}, %{from_node_id: node1.id, to_node_id: node2.id})
      assert Ecto.Changeset.get_field(changeset, :edge_type) == :leads_to
    end

    test "rejects self-links" do
      node = create_node!()

      changeset = GraphEdge.changeset(%GraphEdge{}, %{from_node_id: node.id, to_node_id: node.id})
      refute changeset.valid?
      assert errors_on(changeset)[:to_node_id]
    end

    test "invalid without from_node_id" do
      node = create_node!()
      changeset = GraphEdge.changeset(%GraphEdge{}, %{to_node_id: node.id})
      refute changeset.valid?
    end

    test "accepts rationale" do
      node1 = create_node!()
      node2 = create_node!(%{title: "Other"})

      changeset =
        GraphEdge.changeset(%GraphEdge{}, %{
          from_node_id: node1.id,
          to_node_id: node2.id,
          rationale: "Because reasons",
          edge_type: :chosen
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :rationale) == "Because reasons"
      assert Ecto.Changeset.get_field(changeset, :edge_type) == :chosen
    end
  end

  describe "CRUD operations" do
    test "insert and retrieve an edge" do
      node1 = create_node!(%{title: "Goal"})
      node2 = create_node!(%{title: "Option", node_type: :option})

      {:ok, edge} =
        %GraphEdge{}
        |> GraphEdge.changeset(%{
          from_node_id: node1.id,
          to_node_id: node2.id,
          rationale: "possible approach"
        })
        |> Repo.insert()

      assert edge.id != nil
      assert edge.from_node_id == node1.id
      assert edge.to_node_id == node2.id
      assert edge.edge_type == :leads_to

      fetched = Repo.get!(GraphEdge, edge.id)
      assert fetched.rationale == "possible approach"
    end

    test "insert all edge types" do
      for edge_type <- GraphEdge.edge_types() do
        node1 = create_node!(%{title: "From #{edge_type}"})
        node2 = create_node!(%{title: "To #{edge_type}"})

        {:ok, edge} =
          %GraphEdge{}
          |> GraphEdge.changeset(%{from_node_id: node1.id, to_node_id: node2.id, edge_type: edge_type})
          |> Repo.insert()

        assert edge.edge_type == edge_type
      end
    end

    test "cascade deletes edges when node is deleted" do
      node1 = create_node!(%{title: "Will be deleted"})
      node2 = create_node!(%{title: "Stays"})

      {:ok, edge} =
        %GraphEdge{}
        |> GraphEdge.changeset(%{from_node_id: node1.id, to_node_id: node2.id})
        |> Repo.insert()

      Repo.delete!(node1)
      assert Repo.get(GraphEdge, edge.id) == nil
    end

    test "enforces unique constraint on from/to/type" do
      node1 = create_node!(%{title: "A"})
      node2 = create_node!(%{title: "B"})

      {:ok, _} =
        %GraphEdge{}
        |> GraphEdge.changeset(%{from_node_id: node1.id, to_node_id: node2.id, edge_type: :leads_to})
        |> Repo.insert()

      {:error, changeset} =
        %GraphEdge{}
        |> GraphEdge.changeset(%{from_node_id: node1.id, to_node_id: node2.id, edge_type: :leads_to})
        |> Repo.insert()

      assert errors_on(changeset)[:from_node_id] || errors_on(changeset)[:to_node_id]
    end
  end
end
