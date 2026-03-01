defmodule Decidulixir.GraphTest do
  use Decidulixir.DataCase, async: true

  alias Decidulixir.Graph

  # ── Helpers ─────────────────────────────────────────────

  defp create_node(attrs \\ %{}) do
    default = %{node_type: :goal, title: "Test Goal"}
    {:ok, node} = Graph.create_node(Map.merge(default, attrs))
    node
  end

  defp create_linked_pair do
    goal = create_node(%{node_type: :goal, title: "Root Goal"})
    option = create_node(%{node_type: :option, title: "Option A"})
    {:ok, edge} = Graph.create_edge(goal.id, option.id, %{edge_type: :leads_to, rationale: "test"})
    {goal, option, edge}
  end

  # ── Node CRUD ─────────────────────────────────────────────

  describe "create_node/1" do
    test "creates a node with required fields" do
      {:ok, node} = Graph.create_node(%{node_type: :goal, title: "My Goal"})
      assert node.id
      assert node.change_id
      assert node.node_type == :goal
      assert node.title == "My Goal"
      assert node.status == :active
    end

    test "creates with metadata" do
      {:ok, node} =
        Graph.create_node(%{
          node_type: :action,
          title: "Do thing",
          metadata: %{"confidence" => 85, "branch" => "main"}
        })

      assert node.metadata["confidence"] == 85
      assert node.metadata["branch"] == "main"
    end

    test "fails without required fields" do
      {:error, changeset} = Graph.create_node(%{})
      assert errors_on(changeset)[:node_type]
      assert errors_on(changeset)[:title]
    end
  end

  describe "get_node/1 and get_node!/1" do
    test "returns node by ID" do
      node = create_node()
      assert Graph.get_node(node.id).title == node.title
    end

    test "returns nil for missing ID" do
      assert Graph.get_node(999_999) == nil
    end

    test "raises for missing ID with bang" do
      assert_raise Ecto.NoResultsError, fn ->
        Graph.get_node!(999_999)
      end
    end
  end

  describe "get_node_by_change_id/1" do
    test "finds node by UUID change_id" do
      node = create_node()
      found = Graph.get_node_by_change_id(node.change_id)
      assert found.id == node.id
    end

    test "returns nil for unknown change_id" do
      assert Graph.get_node_by_change_id(Ecto.UUID.generate()) == nil
    end
  end

  describe "update_node/2" do
    test "updates title and description" do
      node = create_node()
      {:ok, updated} = Graph.update_node(node, %{title: "New Title", description: "desc"})
      assert updated.title == "New Title"
      assert updated.description == "desc"
    end

    test "updates status" do
      node = create_node()
      {:ok, updated} = Graph.update_node(node, %{status: :superseded})
      assert updated.status == :superseded
    end
  end

  describe "update_node_status/2" do
    test "updates status by ID" do
      node = create_node()
      {:ok, updated} = Graph.update_node_status(node.id, :abandoned)
      assert updated.status == :abandoned
    end
  end

  describe "update_node_prompt/2" do
    test "sets prompt in metadata" do
      node = create_node()
      {:ok, updated} = Graph.update_node_prompt(node.id, "user said this")
      assert updated.metadata["prompt"] == "user said this"
    end

    test "preserves existing metadata" do
      node = create_node(%{metadata: %{"confidence" => 90}})
      {:ok, updated} = Graph.update_node_prompt(node.id, "hello")
      assert updated.metadata["prompt"] == "hello"
      assert updated.metadata["confidence"] == 90
    end
  end

  describe "delete_node/2" do
    test "deletes node and its edges" do
      {goal, _option, _edge} = create_linked_pair()
      {:ok, result} = Graph.delete_node(goal.id)
      assert result.node.id == goal.id
      assert result.edges_removed == 1
      assert Graph.get_node(goal.id) == nil
    end

    test "dry run does not delete" do
      {goal, _option, _edge} = create_linked_pair()
      {:ok, result} = Graph.delete_node(goal.id, dry_run: true)
      assert result.edges_removed == 1
      assert Graph.get_node(goal.id) != nil
    end

    test "returns error for missing node" do
      assert Graph.delete_node(999_999) == {:error, :not_found}
    end
  end

  # ── Edge CRUD ─────────────────────────────────────────────

  describe "create_edge/3" do
    test "creates edge between nodes" do
      n1 = create_node(%{title: "From"})
      n2 = create_node(%{title: "To"})
      {:ok, edge} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to})
      assert edge.from_node_id == n1.id
      assert edge.to_node_id == n2.id
      assert edge.edge_type == :leads_to
    end

    test "creates edge with rationale" do
      n1 = create_node()
      n2 = create_node(%{title: "Other"})
      {:ok, edge} = Graph.create_edge(n1.id, n2.id, %{rationale: "because"})
      assert edge.rationale == "because"
    end
  end

  describe "delete_edge/2" do
    test "removes edges between two nodes" do
      {goal, option, _edge} = create_linked_pair()
      {:ok, count} = Graph.delete_edge(goal.id, option.id)
      assert count == 1
      assert Graph.edges_from(goal.id) == []
    end
  end

  describe "edges_from/1 and edges_to/1" do
    test "returns outgoing edges" do
      {goal, _option, _edge} = create_linked_pair()
      edges = Graph.edges_from(goal.id)
      assert length(edges) == 1
    end

    test "returns incoming edges" do
      {_goal, option, _edge} = create_linked_pair()
      edges = Graph.edges_to(option.id)
      assert length(edges) == 1
    end
  end

  # ── List queries ──────────────────────────────────────────

  describe "list_nodes/1" do
    test "returns all nodes unfiltered" do
      create_node(%{node_type: :goal, title: "G"})
      create_node(%{node_type: :action, title: "A"})
      assert length(Graph.list_nodes()) == 2
    end

    test "filters by node_type" do
      create_node(%{node_type: :goal, title: "G"})
      create_node(%{node_type: :action, title: "A"})
      result = Graph.list_nodes(node_type: :goal)
      assert length(result) == 1
      assert hd(result).node_type == :goal
    end

    test "filters by status" do
      create_node(%{title: "Active", status: :active})
      create_node(%{title: "Superseded", status: :superseded})
      result = Graph.list_nodes(status: :active)
      assert length(result) == 1
      assert hd(result).title == "Active"
    end

    test "filters by search term" do
      create_node(%{title: "Auth Flow"})
      create_node(%{title: "Rate Limiting"})
      result = Graph.list_nodes(search: "auth")
      assert length(result) == 1
      assert hd(result).title == "Auth Flow"
    end

    test "combines filters" do
      create_node(%{node_type: :goal, title: "Active Goal", status: :active})
      create_node(%{node_type: :goal, title: "Dead Goal", status: :abandoned})
      create_node(%{node_type: :action, title: "Active Action", status: :active})
      result = Graph.list_nodes(node_type: :goal, status: :active)
      assert length(result) == 1
      assert hd(result).title == "Active Goal"
    end
  end

  describe "list_edges/1" do
    test "returns all edges unfiltered" do
      {_goal, _option, _edge} = create_linked_pair()
      assert length(Graph.list_edges()) == 1
    end

    test "filters by edge_type" do
      {g, o, _} = create_linked_pair()
      Graph.create_edge(o.id, g.id, %{edge_type: :requires})
      result = Graph.list_edges(edge_type: :requires)
      assert length(result) == 1
    end
  end

  describe "get_graph/1" do
    test "returns nodes and edges" do
      create_linked_pair()
      graph = Graph.get_graph()
      assert length(graph.nodes) == 2
      assert length(graph.edges) == 1
    end
  end

  # ── Convenience ───────────────────────────────────────────

  describe "active_goals/0" do
    test "returns only active goals" do
      create_node(%{node_type: :goal, title: "Active", status: :active})
      create_node(%{node_type: :goal, title: "Dead", status: :abandoned})
      create_node(%{node_type: :action, title: "Not a goal", status: :active})
      goals = Graph.active_goals()
      assert length(goals) == 1
      assert hd(goals).title == "Active"
    end
  end

  describe "recent_decisions/1" do
    test "returns recent decisions and options" do
      create_node(%{node_type: :decision, title: "D1"})
      create_node(%{node_type: :option, title: "O1"})
      create_node(%{node_type: :goal, title: "G1"})
      result = Graph.recent_decisions(10)
      assert length(result) == 2
      types = Enum.map(result, & &1.node_type)
      assert :decision in types
      assert :option in types
    end
  end

  describe "supersede/3" do
    test "marks old node superseded and creates edge" do
      old = create_node(%{title: "Old approach"})
      new = create_node(%{title: "New approach"})
      {:ok, result} = Graph.supersede(old.id, new.id, "old way was slow")
      assert result.status.status == :superseded
      assert result.edge.from_node_id == old.id
      assert result.edge.to_node_id == new.id
      assert result.edge.rationale == "old way was slow"
    end
  end

  # ── Conversation Sets ─────────────────────────────────────

  describe "conversation sets" do
    test "creates set and adds nodes" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, set} = Graph.create_conversation_set(%{started_at: now, name: "Session 1"})
      node = create_node(%{title: "In session"})
      {:ok, _join} = Graph.add_node_to_conversation_set(node.id, set.id)

      nodes = Graph.nodes_in_conversation_set(set.id)
      assert length(nodes) == 1
      assert hd(nodes).id == node.id
    end
  end

  # ── Stats ─────────────────────────────────────────────────

  describe "graph_stats/0" do
    test "returns counts" do
      create_linked_pair()
      stats = Graph.graph_stats()
      assert stats.nodes == 2
      assert stats.edges == 1
    end
  end

  describe "node_counts_by_type/0" do
    test "returns breakdown by type" do
      create_node(%{node_type: :goal, title: "G"})
      create_node(%{node_type: :goal, title: "G2"})
      create_node(%{node_type: :action, title: "A"})
      counts = Graph.node_counts_by_type()
      assert counts[:goal] == 2
      assert counts[:action] == 1
    end
  end
end
