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

  describe "GET /api/graph filters" do
    test "filters by status", %{conn: conn} do
      create_node!(%{title: "Active One", status: :active})
      create_node!(%{title: "Gone One", status: :abandoned})

      conn = get(conn, ~p"/api/graph?status=active")
      %{"nodes" => nodes} = json_response(conn, 200)
      assert length(nodes) == 1
      assert hd(nodes)["title"] == "Active One"
    end

    test "filters by search", %{conn: conn} do
      create_node!(%{title: "Authentication Flow"})
      create_node!(%{title: "Throttle Mechanism"})

      conn = get(conn, ~p"/api/graph?search=auth")
      %{"nodes" => nodes} = json_response(conn, 200)
      assert length(nodes) == 1
      assert hd(nodes)["title"] == "Authentication Flow"
    end

    test "combines type and status filters", %{conn: conn} do
      create_node!(%{title: "Active Goal", node_type: :goal, status: :active})
      create_node!(%{title: "Abandoned Goal", node_type: :goal, status: :abandoned})
      create_node!(%{title: "Active Action", node_type: :action, status: :active})

      conn = get(conn, ~p"/api/graph?type=goal&status=active")
      %{"nodes" => nodes} = json_response(conn, 200)
      assert length(nodes) == 1
      assert hd(nodes)["title"] == "Active Goal"
    end
  end

  describe "GET /api/graph/:id edges" do
    test "returns outgoing edges", %{conn: conn} do
      n1 = create_node!(%{title: "Parent"})
      n2 = create_node!(%{title: "Child", node_type: :option})
      {:ok, edge} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to, rationale: "test"})

      conn = get(conn, ~p"/api/graph/#{n1.id}")
      %{"outgoing_edges" => out} = json_response(conn, 200)
      assert length(out) == 1
      assert hd(out)["id"] == edge.id
      assert hd(out)["edge_type"] == "leads_to"
      assert hd(out)["rationale"] == "test"
    end

    test "returns incoming edges", %{conn: conn} do
      n1 = create_node!(%{title: "Parent"})
      n2 = create_node!(%{title: "Child", node_type: :option})
      {:ok, _edge} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to})

      conn = get(conn, ~p"/api/graph/#{n2.id}")
      %{"incoming_edges" => inc} = json_response(conn, 200)
      assert length(inc) == 1
      assert hd(inc)["from_node_id"] == n1.id
    end

    test "serializes all node fields", %{conn: conn} do
      node =
        create_node!(%{
          title: "Full Node",
          description: "A description",
          node_type: :decision,
          status: :completed,
          metadata: %{"confidence" => 90}
        })

      conn = get(conn, ~p"/api/graph/#{node.id}")
      %{"node" => n} = json_response(conn, 200)
      assert n["title"] == "Full Node"
      assert n["description"] == "A description"
      assert n["node_type"] == "decision"
      assert n["status"] == "completed"
      assert n["metadata"] == %{"confidence" => 90}
      assert n["change_id"] == node.change_id
      assert n["id"] == node.id
    end
  end

  describe "GET /api/graph edges in index" do
    test "includes edges in index response", %{conn: conn} do
      n1 = create_node!(%{title: "N1"})
      n2 = create_node!(%{title: "N2", node_type: :option})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to})

      conn = get(conn, ~p"/api/graph")
      %{"edges" => edges} = json_response(conn, 200)
      assert length(edges) == 1
      assert hd(edges)["from_node_id"] == n1.id
      assert hd(edges)["to_node_id"] == n2.id
    end

    test "includes stats with node and edge counts", %{conn: conn} do
      n1 = create_node!(%{title: "N1"})
      n2 = create_node!(%{title: "N2", node_type: :option})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to})

      conn = get(conn, ~p"/api/graph")
      %{"stats" => stats} = json_response(conn, 200)
      assert stats["nodes"] == 2
      assert stats["edges"] == 1
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

    test "returns zero counts for empty graph", %{conn: conn} do
      conn = get(conn, ~p"/api/graph/stats")
      %{"stats" => stats, "by_type" => by_type} = json_response(conn, 200)
      assert stats["nodes"] == 0
      assert stats["edges"] == 0
      assert by_type == %{}
    end
  end
end
