defmodule Decidulixir.Graph.TraversalTest do
  use Decidulixir.DataCase, async: true

  alias Decidulixir.Graph
  alias Decidulixir.Graph.Traversal

  defp create_node!(attrs) do
    {:ok, node} = Graph.create_node(Map.merge(%{node_type: :goal, title: "Test"}, attrs))
    node
  end

  defp link!(from, to) do
    {:ok, _} = Graph.create_edge(from.id, to.id)
  end

  # Build a tree:  A → B → D
  #                A → C → E
  defp build_tree do
    a = create_node!(%{title: "A"})
    b = create_node!(%{title: "B", node_type: :option})
    c = create_node!(%{title: "C", node_type: :option})
    d = create_node!(%{title: "D", node_type: :decision})
    e = create_node!(%{title: "E", node_type: :decision})

    link!(a, b)
    link!(a, c)
    link!(b, d)
    link!(c, e)

    %{a: a, b: b, c: c, d: d, e: e}
  end

  describe "children/1" do
    test "returns immediate children" do
      %{a: a, b: b, c: c} = build_tree()
      children = Traversal.children(a.id)
      ids = Enum.map(children, & &1.id) |> Enum.sort()
      assert ids == Enum.sort([b.id, c.id])
    end

    test "returns empty for leaf node" do
      %{d: d} = build_tree()
      assert Traversal.children(d.id) == []
    end
  end

  describe "parents/1" do
    test "returns immediate parents" do
      %{a: a, b: b} = build_tree()
      parents = Traversal.parents(b.id)
      assert length(parents) == 1
      assert hd(parents).id == a.id
    end

    test "returns empty for root node" do
      %{a: a} = build_tree()
      assert Traversal.parents(a.id) == []
    end
  end

  describe "bfs/2" do
    test "outgoing BFS traverses all descendants" do
      %{a: a} = build_tree()
      nodes = Traversal.bfs(a.id, :outgoing)
      assert length(nodes) == 5
    end

    test "incoming BFS traverses ancestors" do
      %{d: d, b: b, a: a} = build_tree()
      nodes = Traversal.bfs(d.id, :incoming)
      ids = Enum.map(nodes, & &1.id)
      assert a.id in ids
      assert b.id in ids
      assert d.id in ids
    end

    test "both BFS finds entire component" do
      %{a: _a, d: d} = build_tree()
      nodes = Traversal.bfs(d.id, :both)
      assert length(nodes) == 5
    end

    test "isolated node returns just itself" do
      loner = create_node!(%{title: "Alone"})
      nodes = Traversal.bfs(loner.id, :outgoing)
      assert length(nodes) == 1
      assert hd(nodes).id == loner.id
    end
  end

  describe "bfs_descendants/1" do
    test "returns descendants excluding start node" do
      %{a: a} = build_tree()
      descendants = Traversal.bfs_descendants(a.id)
      assert length(descendants) == 4
      ids = Enum.map(descendants, & &1.id)
      refute a.id in ids
    end
  end

  describe "connected_component/1" do
    test "returns all nodes and edges in component" do
      %{a: _a, c: c} = build_tree()
      component = Traversal.connected_component(c.id)
      assert length(component.nodes) == 5
      assert length(component.edges) == 4
    end

    test "disconnected node returns single-node component" do
      loner = create_node!(%{title: "Alone"})
      component = Traversal.connected_component(loner.id)
      assert length(component.nodes) == 1
      assert component.edges == []
    end

    test "two separate components are independent" do
      %{a: _} = build_tree()
      separate = create_node!(%{title: "Separate"})
      component = Traversal.connected_component(separate.id)
      assert length(component.nodes) == 1
    end
  end
end
