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
      assert html =~ "0 nodes"
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

    test "shows node count", %{conn: conn} do
      create_node!(%{title: "N1"})
      create_node!(%{title: "N2"})
      create_node!(%{title: "N3"})

      {:ok, _view, html} = live(conn, ~p"/graph")
      assert html =~ "3 nodes"
    end

    test "filters via phx-change event", %{conn: conn} do
      create_node!(%{title: "GoalQQQ Node", node_type: :goal})
      create_node!(%{title: "ActionQQQ Node", node_type: :action})

      {:ok, view, _html} = live(conn, ~p"/graph")

      html =
        view
        |> element("form")
        |> render_change(%{
          "filter" => %{"type" => "goal", "status" => "", "search" => "", "branch" => ""}
        })

      # After filter event, the view patches to the filtered URL
      assert html =~ "GoalQQQ Node"
      refute html =~ "ActionQQQ Node"
    end

    test "shows type badges on node cards", %{conn: conn} do
      create_node!(%{title: "Badge Node", node_type: :decision})

      {:ok, _view, html} = live(conn, ~p"/graph")
      assert html =~ "decision"
    end

    test "shows confidence badge when present", %{conn: conn} do
      create_node!(%{title: "Confident Node", metadata: %{"confidence" => 95}})

      {:ok, _view, html} = live(conn, ~p"/graph")
      assert html =~ "95%"
    end

    test "shows branch on node card", %{conn: conn} do
      create_node!(%{title: "Branch Node", metadata: %{"branch" => "feature-xyz"}})

      {:ok, _view, html} = live(conn, ~p"/graph")
      assert html =~ "feature-xyz"
    end

    test "combines type and status filters via URL", %{conn: conn} do
      create_node!(%{title: "Active Goal ZQZ", node_type: :goal, status: :active})
      create_node!(%{title: "Dead Goal ZQZ", node_type: :goal, status: :abandoned})
      create_node!(%{title: "Active Action ZQZ", node_type: :action, status: :active})

      {:ok, _view, html} = live(conn, ~p"/graph?type=goal&status=active")
      assert html =~ "Active Goal ZQZ"
      refute html =~ "Dead Goal ZQZ"
      refute html =~ "Active Action ZQZ"
    end

    test "shows stats breakdown by type", %{conn: conn} do
      create_node!(%{title: "G1", node_type: :goal})
      create_node!(%{title: "G2", node_type: :goal})
      create_node!(%{title: "A1", node_type: :action})

      {:ok, _view, html} = live(conn, ~p"/graph")
      assert html =~ "goal"
      assert html =~ "action"
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

    test "shows edge rationale", %{conn: conn} do
      n1 = create_node!(%{title: "Source"})
      n2 = create_node!(%{title: "Target", node_type: :option})

      {:ok, _} =
        Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to, rationale: "Important reason"})

      {:ok, _view, html} = live(conn, ~p"/graph/#{n1.id}")
      assert html =~ "Important reason"
    end

    test "shows edge count", %{conn: conn} do
      n1 = create_node!(%{title: "Hub"})
      n2 = create_node!(%{title: "Spoke1", node_type: :option})
      n3 = create_node!(%{title: "Spoke2", node_type: :action})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to})
      {:ok, _} = Graph.create_edge(n1.id, n3.id, %{edge_type: :leads_to})

      {:ok, _view, html} = live(conn, ~p"/graph/#{n1.id}")
      assert html =~ "Outgoing Edges (2)"
    end

    test "shows node timestamps", %{conn: conn} do
      node = create_node!(%{title: "Timestamped"})
      {:ok, _view, html} = live(conn, ~p"/graph/#{node.id}")
      assert html =~ "Created:"
      assert html =~ "Updated:"
    end

    test "links to edge targets", %{conn: conn} do
      n1 = create_node!(%{title: "From"})
      n2 = create_node!(%{title: "To", node_type: :option})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to})

      {:ok, _view, html} = live(conn, ~p"/graph/#{n1.id}")
      assert html =~ "/graph/#{n2.id}"
    end

    test "shows page title with node info", %{conn: conn} do
      node = create_node!(%{title: "Title Check"})
      {:ok, _view, html} = live(conn, ~p"/graph/#{node.id}")
      assert html =~ "Node #{node.id}"
    end

    test "redirects for non-integer ID", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/graph"}}} = live(conn, ~p"/graph/abc")
    end

    test "hides metadata section when empty", %{conn: conn} do
      node = create_node!(%{title: "No Meta"})
      {:ok, _view, html} = live(conn, ~p"/graph/#{node.id}")
      refute html =~ "Metadata"
    end

    test "shows branch in metadata", %{conn: conn} do
      node = create_node!(%{title: "Branch Meta", metadata: %{"branch" => "feat-xyz"}})
      {:ok, _view, html} = live(conn, ~p"/graph/#{node.id}")
      assert html =~ "branch"
      assert html =~ "feat-xyz"
    end

    test "shows both incoming and outgoing edges", %{conn: conn} do
      n1 = create_node!(%{title: "Before"})
      n2 = create_node!(%{title: "Middle", node_type: :decision})
      n3 = create_node!(%{title: "After", node_type: :action})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to})
      {:ok, _} = Graph.create_edge(n2.id, n3.id, %{edge_type: :leads_to})

      {:ok, _view, html} = live(conn, ~p"/graph/#{n2.id}")
      assert html =~ "Incoming Edges"
      assert html =~ "Outgoing Edges"
    end
  end
end
