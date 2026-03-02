defmodule DecidulixirWeb.GraphLiveTest do
  use DecidulixirWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Decidulixir.Graph

  defp create_node!(attrs) do
    {:ok, node} = Graph.create_node(Map.merge(%{node_type: :goal, title: "Test"}, attrs))
    node
  end

  describe "GraphLive.Index" do
    test "renders graph index", %{conn: conn} do
      create_node!(%{title: "My Goal", node_type: :goal})
      create_node!(%{title: "My Action", node_type: :action})

      {:ok, _view, html} = live(conn, ~p"/graph")
      assert html =~ "Decision Graph"
      assert html =~ "My Goal"
      assert html =~ "My Action"
    end

    test "renders empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/graph")
      assert html =~ "Decision Graph"
    end

    test "filters by type", %{conn: conn} do
      create_node!(%{title: "Goal XYZ Node", node_type: :goal})
      create_node!(%{title: "Action XYZ Node", node_type: :action})

      {:ok, _view, html} = live(conn, ~p"/graph?type=goal")
      assert html =~ "Goal XYZ Node"
      # The filtered-out node title should not appear in the cards
      refute html =~ "Action XYZ Node"
    end

    test "filters by status", %{conn: conn} do
      create_node!(%{title: "ActiveZZZ One", status: :active})
      create_node!(%{title: "GoneZZZ One", status: :abandoned})

      {:ok, _view, html} = live(conn, ~p"/graph?status=active")
      assert html =~ "ActiveZZZ One"
      refute html =~ "GoneZZZ One"
    end

    test "filters by search", %{conn: conn} do
      create_node!(%{title: "Authentication Flow"})
      create_node!(%{title: "Throttle Mechanism"})

      {:ok, _view, html} = live(conn, ~p"/graph?search=auth")
      assert html =~ "Authentication Flow"
      refute html =~ "Throttle Mechanism"
    end

    test "shows stats panel", %{conn: conn} do
      create_node!(%{title: "G1", node_type: :goal})
      create_node!(%{title: "A1", node_type: :action})

      {:ok, _view, html} = live(conn, ~p"/graph")
      assert html =~ "Nodes"
      assert html =~ "Edges"
    end

    test "links to node detail", %{conn: conn} do
      node = create_node!(%{title: "Clickable"})
      {:ok, _view, html} = live(conn, ~p"/graph")
      assert html =~ "/graph/#{node.id}"
    end
  end

  describe "GraphLive.Show" do
    test "renders node detail", %{conn: conn} do
      node = create_node!(%{title: "Detail Node", description: "Has description"})
      {:ok, _view, html} = live(conn, ~p"/graph/#{node.id}")
      assert html =~ "Detail Node"
      assert html =~ "Has description"
      assert html =~ node.change_id
    end

    test "shows edges", %{conn: conn} do
      n1 = create_node!(%{title: "Parent"})
      n2 = create_node!(%{title: "Child", node_type: :option})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to, rationale: "test"})

      {:ok, _view, html} = live(conn, ~p"/graph/#{n1.id}")
      assert html =~ "Outgoing Edges"
      assert html =~ "leads_to"
    end

    test "shows incoming edges", %{conn: conn} do
      n1 = create_node!(%{title: "Parent"})
      n2 = create_node!(%{title: "Child", node_type: :option})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to})

      {:ok, _view, html} = live(conn, ~p"/graph/#{n2.id}")
      assert html =~ "Incoming Edges"
    end

    test "redirects for missing node", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/graph"}}} = live(conn, ~p"/graph/999999")
    end

    test "shows metadata", %{conn: conn} do
      node =
        create_node!(%{title: "With Meta", metadata: %{"confidence" => 85, "branch" => "main"}})

      {:ok, _view, html} = live(conn, ~p"/graph/#{node.id}")
      assert html =~ "Metadata"
      assert html =~ "confidence"
      assert html =~ "85"
    end

    test "has back link", %{conn: conn} do
      node = create_node!(%{title: "Back Test"})
      {:ok, _view, html} = live(conn, ~p"/graph/#{node.id}")
      assert html =~ "/graph"
      assert html =~ "Back"
    end
  end
end
