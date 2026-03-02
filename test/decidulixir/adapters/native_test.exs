defmodule Decidulixir.Adapters.DecisionGraph.NativeTest do
  use Decidulixir.DataCase, async: true
  use Decidulixir.AdapterConformance, adapter: Decidulixir.Adapters.DecisionGraph.Native

  alias Decidulixir.Adapters.DecisionGraph.Native

  describe "native-specific features" do
    test "get_node works with integer ID" do
      {:ok, node} = Native.create_node(%{node_type: :goal, title: "Int ID"})
      # Native returns integer IDs
      assert is_integer(node.id)
      {:ok, fetched} = Native.get_node(node.id)
      assert fetched.title == "Int ID"
    end

    test "get_node works with UUID change_id" do
      {:ok, node} = Native.create_node(%{node_type: :goal, title: "UUID Lookup"})
      {:ok, fetched} = Native.get_node(node.change_id)
      assert fetched.title == "UUID Lookup"
    end

    test "supersede marks old and creates edge" do
      {:ok, old} = Native.create_node(%{node_type: :goal, title: "Old"})
      {:ok, new} = Native.create_node(%{node_type: :goal, title: "New"})
      {:ok, edge} = Native.supersede(old.id, new.id, "old was slow")
      assert edge.rationale == "old was slow"

      {:ok, old_updated} = Native.get_node(old.id)
      assert old_updated.status == :superseded
    end

    test "pulse detects orphans" do
      {:ok, _} = Native.create_node(%{node_type: :action, title: "Orphaned"})
      {:ok, report} = Native.pulse()
      assert report.orphan_nodes != []
    end

    test "pulse detects coverage gaps" do
      {:ok, _} = Native.create_node(%{node_type: :goal, title: "No children"})
      {:ok, report} = Native.pulse()
      gaps = report.coverage_gaps
      assert Enum.any?(gaps, fn g -> g.title == "No children" end)
    end
  end
end
