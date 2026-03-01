defmodule Decidulixir.Graph.QueriesTest do
  use Decidulixir.DataCase, async: true

  alias Decidulixir.Graph.GraphEdge
  alias Decidulixir.Graph.Node
  alias Decidulixir.Graph.Queries

  defp create_node!(attrs) do
    %Node{}
    |> Node.changeset(Map.merge(%{node_type: :goal, title: "Test"}, attrs))
    |> Repo.insert!()
  end

  defp create_edge!(from, to, attrs \\ %{}) do
    %GraphEdge{}
    |> GraphEdge.changeset(Map.merge(%{from_node_id: from.id, to_node_id: to.id}, attrs))
    |> Repo.insert!()
  end

  describe "by_type/2" do
    test "filters nodes by type" do
      create_node!(%{node_type: :goal, title: "G"})
      create_node!(%{node_type: :action, title: "A"})

      result = Node |> Queries.by_type(:goal) |> Repo.all()
      assert length(result) == 1
      assert hd(result).node_type == :goal
    end
  end

  describe "by_status/2" do
    test "filters nodes by status" do
      create_node!(%{title: "Active", status: :active})
      create_node!(%{title: "Gone", status: :abandoned})

      result = Node |> Queries.by_status(:active) |> Repo.all()
      assert length(result) == 1
      assert hd(result).title == "Active"
    end
  end

  describe "by_branch/2" do
    test "filters by branch in metadata jsonb" do
      create_node!(%{title: "Main", metadata: %{"branch" => "main"}})
      create_node!(%{title: "Feature", metadata: %{"branch" => "feature-x"}})

      result = Node |> Queries.by_branch("main") |> Repo.all()
      assert length(result) == 1
      assert hd(result).title == "Main"
    end
  end

  describe "recent/2" do
    test "limits and orders by inserted_at desc" do
      for i <- 1..5, do: create_node!(%{title: "Node #{i}"})

      result = Node |> Queries.recent(3) |> Repo.all()
      assert length(result) == 3
    end
  end

  describe "search_title/2" do
    test "case-insensitive title search" do
      create_node!(%{title: "Authentication Flow"})
      create_node!(%{title: "Rate Limiting"})

      result = Node |> Queries.search_title("auth") |> Repo.all()
      assert length(result) == 1
      assert hd(result).title == "Authentication Flow"
    end
  end

  describe "search_title_or_description/2" do
    test "searches both title and description" do
      create_node!(%{title: "Other", description: "uses JWT tokens"})
      create_node!(%{title: "JWT Setup", description: nil})

      result = Node |> Queries.search_title_or_description("jwt") |> Repo.all()
      assert length(result) == 2
    end
  end

  describe "composability" do
    test "pipes multiple filters" do
      create_node!(%{node_type: :goal, title: "Active Goal", status: :active})
      create_node!(%{node_type: :goal, title: "Dead Goal", status: :abandoned})
      create_node!(%{node_type: :action, title: "Active Action", status: :active})

      result =
        Node
        |> Queries.by_type(:goal)
        |> Queries.by_status(:active)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).title == "Active Goal"
    end
  end

  describe "edge queries" do
    test "by_edge_type/2 filters edges" do
      n1 = create_node!(%{title: "From"})
      n2 = create_node!(%{title: "To"})
      create_edge!(n1, n2, %{edge_type: :leads_to})
      create_edge!(n2, n1, %{edge_type: :requires})

      result = GraphEdge |> Queries.by_edge_type(:requires) |> Repo.all()
      assert length(result) == 1
      assert hd(result).edge_type == :requires
    end

    test "edges_from/2 returns outgoing" do
      n1 = create_node!(%{title: "From"})
      n2 = create_node!(%{title: "To"})
      create_edge!(n1, n2)

      result = GraphEdge |> Queries.edges_from(n1.id) |> Repo.all()
      assert length(result) == 1
    end

    test "edges_to/2 returns incoming" do
      n1 = create_node!(%{title: "From"})
      n2 = create_node!(%{title: "To"})
      create_edge!(n1, n2)

      result = GraphEdge |> Queries.edges_to(n2.id) |> Repo.all()
      assert length(result) == 1
    end

    test "edges_involving/2 returns both directions" do
      n1 = create_node!(%{title: "A"})
      n2 = create_node!(%{title: "B"})
      n3 = create_node!(%{title: "C"})
      create_edge!(n1, n2)
      create_edge!(n3, n1)

      result = GraphEdge |> Queries.edges_involving(n1.id) |> Repo.all()
      assert length(result) == 2
    end
  end
end
