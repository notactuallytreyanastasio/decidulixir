defmodule Decidulixir.Adapters.DecisionGraph.LoomTest do
  use Decidulixir.DataCase, async: true
  use Decidulixir.AdapterConformance, adapter: Decidulixir.Adapters.DecisionGraph.Loom

  alias Decidulixir.Adapters.DecisionGraph.Loom, as: LoomAdapter
  alias Decidulixir.Graph
  alias Decidulixir.Graph.Node
  alias Decidulixir.Repo

  describe "UUID ID translation" do
    test "returns UUID as id (Loom format)" do
      {:ok, node} = LoomAdapter.create_node(%{node_type: :goal, title: "UUID Test"})
      assert is_binary(node.id)
      # UUID format: 8-4-4-4-12
      assert String.match?(
               node.id,
               ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
             )
    end

    test "get_node accepts UUID" do
      {:ok, node} = LoomAdapter.create_node(%{node_type: :goal, title: "Get UUID"})
      {:ok, fetched} = LoomAdapter.get_node(node.id)
      assert fetched.title == "Get UUID"
    end

    test "update_node accepts UUID" do
      {:ok, node} = LoomAdapter.create_node(%{node_type: :goal, title: "Before"})
      {:ok, updated} = LoomAdapter.update_node(node.id, %{title: "After"})
      assert updated.title == "After"
    end

    test "delete_node accepts UUID" do
      {:ok, node} = LoomAdapter.create_node(%{node_type: :goal, title: "Delete UUID"})
      {:ok, deleted} = LoomAdapter.delete_node(node.id)
      assert deleted.title == "Delete UUID"
      assert {:error, :not_found} = LoomAdapter.get_node(node.id)
    end
  end

  describe "confidence translation" do
    test "stores confidence in metadata" do
      {:ok, node} =
        LoomAdapter.create_node(%{node_type: :goal, title: "Confident", confidence: 85})

      # Loom sees confidence as top-level field
      assert node.confidence == 85

      # Decidulixir stores it in metadata
      db_node = Repo.get_by!(Node, change_id: node.id)
      assert db_node.metadata["confidence"] == 85
    end

    test "confidence absent when not set" do
      {:ok, node} = LoomAdapter.create_node(%{node_type: :goal, title: "No Confidence"})
      assert node.confidence == nil
    end
  end

  describe "agent_name translation" do
    test "stores agent_name in metadata" do
      {:ok, node} =
        LoomAdapter.create_node(%{node_type: :goal, title: "Agent", agent_name: "explorer"})

      assert node.agent_name == "explorer"

      db_node = Repo.get_by!(Node, change_id: node.id)
      assert db_node.metadata["agent_name"] == "explorer"
    end
  end

  describe "edge types" do
    test "supports :supersedes edge type" do
      {:ok, n1} = LoomAdapter.create_node(%{node_type: :goal, title: "Old"})
      {:ok, n2} = LoomAdapter.create_node(%{node_type: :goal, title: "New"})
      {:ok, edge} = LoomAdapter.create_edge(n1.id, n2.id, :supersedes)
      assert edge.edge_type == :supersedes
    end

    test "supports :supports edge type" do
      {:ok, n1} = LoomAdapter.create_node(%{node_type: :observation, title: "Evidence"})
      {:ok, n2} = LoomAdapter.create_node(%{node_type: :decision, title: "Conclusion"})
      {:ok, edge} = LoomAdapter.create_edge(n1.id, n2.id, :supports)
      assert edge.edge_type == :supports
    end
  end

  describe "supersede through Loom" do
    test "supersede works with UUIDs" do
      {:ok, old} = LoomAdapter.create_node(%{node_type: :goal, title: "Old Way"})
      {:ok, new} = LoomAdapter.create_node(%{node_type: :goal, title: "New Way"})
      {:ok, edge} = LoomAdapter.supersede(old.id, new.id, "found a better approach")
      assert edge.rationale == "found a better approach"

      {:ok, old_updated} = LoomAdapter.get_node(old.id)
      assert old_updated.status == :superseded
    end
  end

  describe "round-trip integration" do
    test "create via Loom, query via native Graph context" do
      {:ok, loom_node} =
        LoomAdapter.create_node(%{
          node_type: :goal,
          title: "Round Trip",
          confidence: 90,
          agent_name: "test_agent"
        })

      # Verify via native Decidulixir API
      db_node = Graph.get_node_by_change_id(loom_node.id)
      assert db_node.title == "Round Trip"
      assert db_node.metadata["confidence"] == 90
      assert db_node.metadata["agent_name"] == "test_agent"
    end

    test "create via native, read via Loom" do
      {:ok, native_node} =
        Graph.create_node(%{
          node_type: :action,
          title: "Native Node",
          metadata: %{"confidence" => 75, "agent_name" => "builder"}
        })

      {:ok, loom_view} = LoomAdapter.get_node(native_node.change_id)
      assert loom_view.title == "Native Node"
      assert loom_view.confidence == 75
      assert loom_view.agent_name == "builder"
    end

    test "create nodes and edges via Loom, verify graph structure" do
      {:ok, goal} = LoomAdapter.create_node(%{node_type: :goal, title: "G"})
      {:ok, opt1} = LoomAdapter.create_node(%{node_type: :option, title: "O1"})
      {:ok, opt2} = LoomAdapter.create_node(%{node_type: :option, title: "O2"})
      {:ok, _} = LoomAdapter.create_edge(goal.id, opt1.id, :leads_to)
      {:ok, _} = LoomAdapter.create_edge(goal.id, opt2.id, :leads_to)

      # Verify structure via native API
      edges = Graph.edges_from(Graph.get_node_by_change_id(goal.id).id)
      assert length(edges) == 2
    end
  end
end
