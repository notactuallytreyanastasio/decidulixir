defmodule DecidulixirWeb.API.GraphControllerTest do
  use DecidulixirWeb.ConnCase, async: true

  alias Decidulixir.Graph

  defp create_node!(attrs) do
    {:ok, node} = Graph.create_node(Map.merge(%{node_type: :goal, title: "Test"}, attrs))
    node
  end

  describe "GET /api/graph" do
    test "returns graph as JSON", %{conn: conn} do
      create_node!(%{title: "API Goal"})

      conn = get(conn, ~p"/api/graph")
      assert %{"nodes" => nodes, "edges" => edges, "stats" => stats} = json_response(conn, 200)
      assert is_list(nodes)
      assert is_list(edges)
      assert is_map(stats)
      assert hd(nodes)["title"] == "API Goal"
    end

    test "filters by type", %{conn: conn} do
      create_node!(%{title: "Goal", node_type: :goal})
      create_node!(%{title: "Action", node_type: :action})

      conn = get(conn, ~p"/api/graph?type=goal")
      %{"nodes" => nodes} = json_response(conn, 200)
      assert length(nodes) == 1
      assert hd(nodes)["node_type"] == "goal"
    end

    test "returns empty graph", %{conn: conn} do
      conn = get(conn, ~p"/api/graph")
      %{"nodes" => nodes, "edges" => edges} = json_response(conn, 200)
      assert nodes == []
      assert edges == []
    end
  end

  describe "GET /api/graph/:id" do
    test "returns node with edges", %{conn: conn} do
      node = create_node!(%{title: "Detail"})

      conn = get(conn, ~p"/api/graph/#{node.id}")
      %{"node" => n, "incoming_edges" => inc, "outgoing_edges" => out} = json_response(conn, 200)
      assert n["title"] == "Detail"
      assert is_list(inc)
      assert is_list(out)
    end

    test "returns 404 for missing node", %{conn: conn} do
      conn = get(conn, ~p"/api/graph/999999")
      assert %{"error" => "not found"} = json_response(conn, 404)
    end

    test "returns 400 for invalid ID", %{conn: conn} do
      conn = get(conn, ~p"/api/graph/abc")
      assert %{"error" => "invalid ID"} = json_response(conn, 400)
    end
  end

  describe "GET /api/graph/stats" do
    test "returns stats", %{conn: conn} do
      create_node!(%{title: "S1", node_type: :goal})
      create_node!(%{title: "S2", node_type: :action})

      conn = get(conn, ~p"/api/graph/stats")
      %{"stats" => stats, "by_type" => by_type} = json_response(conn, 200)
      assert stats["nodes"] == 2
      assert by_type["goal"] == 1
      assert by_type["action"] == 1
    end
  end
end
