defmodule Decidulixir.AdapterConformance do
  @moduledoc """
  Shared conformance tests for DecisionGraph adapter implementations.

  Both Native and Loom adapters must pass all these tests.

  Usage:
      use Decidulixir.AdapterConformance, adapter: MyAdapter
  """

  defmacro __using__(opts) do
    adapter = Keyword.fetch!(opts, :adapter)

    quote do
      describe "#{inspect(unquote(adapter))} conformance" do
        # ── Node CRUD ────────────────────────────────────

        test "create and retrieve a node" do
          {:ok, node} = unquote(adapter).create_node(%{node_type: :goal, title: "Test Goal"})
          assert node.title == "Test Goal"
          assert node.node_type == :goal
          assert node.status == :active

          {:ok, fetched} = unquote(adapter).get_node(node.id)
          assert fetched.title == "Test Goal"
        end

        test "create node with all types" do
          for type <- [:goal, :decision, :option, :action, :outcome, :observation, :revisit] do
            {:ok, node} = unquote(adapter).create_node(%{node_type: type, title: "#{type} node"})
            assert node.node_type == type
          end
        end

        test "update a node" do
          {:ok, node} = unquote(adapter).create_node(%{node_type: :goal, title: "Original"})
          {:ok, updated} = unquote(adapter).update_node(node.id, %{title: "Updated"})
          assert updated.title == "Updated"
        end

        test "delete a node" do
          {:ok, node} = unquote(adapter).create_node(%{node_type: :goal, title: "Delete Me"})
          {:ok, deleted} = unquote(adapter).delete_node(node.id)
          assert deleted.title == "Delete Me"
          assert {:error, :not_found} = unquote(adapter).get_node(node.id)
        end

        test "get non-existent node returns error" do
          # Use a UUID that won't exist
          assert {:error, :not_found} = unquote(adapter).get_node(Ecto.UUID.generate())
        end

        test "list nodes unfiltered" do
          {:ok, _} = unquote(adapter).create_node(%{node_type: :goal, title: "G1"})
          {:ok, _} = unquote(adapter).create_node(%{node_type: :action, title: "A1"})
          {:ok, nodes} = unquote(adapter).list_nodes([])
          assert length(nodes) >= 2
        end

        test "list nodes filtered by type" do
          {:ok, _} = unquote(adapter).create_node(%{node_type: :goal, title: "G"})
          {:ok, _} = unquote(adapter).create_node(%{node_type: :action, title: "A"})
          {:ok, nodes} = unquote(adapter).list_nodes(node_type: :goal)
          assert Enum.all?(nodes, fn n -> n.node_type == :goal end)
        end

        # ── Edge CRUD ────────────────────────────────────

        test "create edge between nodes" do
          {:ok, n1} = unquote(adapter).create_node(%{node_type: :goal, title: "G"})
          {:ok, n2} = unquote(adapter).create_node(%{node_type: :option, title: "O"})
          {:ok, edge} = unquote(adapter).create_edge(n1.id, n2.id, :leads_to)
          assert edge.edge_type == :leads_to
        end

        test "create edge with rationale" do
          {:ok, n1} = unquote(adapter).create_node(%{node_type: :goal, title: "G"})
          {:ok, n2} = unquote(adapter).create_node(%{node_type: :option, title: "O"})

          {:ok, edge} =
            unquote(adapter).create_edge(n1.id, n2.id, :leads_to, rationale: "because")

          assert edge.rationale == "because"
        end

        test "list edges" do
          {:ok, n1} = unquote(adapter).create_node(%{node_type: :goal, title: "G"})
          {:ok, n2} = unquote(adapter).create_node(%{node_type: :option, title: "O"})
          {:ok, _} = unquote(adapter).create_edge(n1.id, n2.id, :leads_to)
          {:ok, edges} = unquote(adapter).list_edges([])
          assert length(edges) >= 1
        end

        # ── Convenience ──────────────────────────────────

        test "active_goals returns only active goals" do
          {:ok, _} = unquote(adapter).create_node(%{node_type: :goal, title: "Active", status: :active})
          {:ok, _} = unquote(adapter).create_node(%{node_type: :goal, title: "Dead", status: :abandoned})
          {:ok, _} = unquote(adapter).create_node(%{node_type: :action, title: "Not Goal", status: :active})
          {:ok, goals} = unquote(adapter).active_goals()
          assert Enum.all?(goals, fn g -> g.node_type == :goal and g.status == :active end)
          assert length(goals) >= 1
        end

        test "recent_decisions returns decisions and options" do
          {:ok, _} = unquote(adapter).create_node(%{node_type: :decision, title: "D"})
          {:ok, _} = unquote(adapter).create_node(%{node_type: :option, title: "O"})
          {:ok, _} = unquote(adapter).create_node(%{node_type: :goal, title: "G"})
          {:ok, result} = unquote(adapter).recent_decisions(10)
          types = Enum.map(result, & &1.node_type)
          assert :decision in types
          assert :option in types
          refute :goal in types
        end

        # ── Analysis ─────────────────────────────────────

        test "build_context returns a string" do
          {:ok, _} = unquote(adapter).create_node(%{node_type: :goal, title: "Context Goal"})
          {:ok, context} = unquote(adapter).build_context(nil)
          assert is_binary(context)
          assert context =~ "Context Goal"
        end

        test "pulse returns a report map" do
          {:ok, _} = unquote(adapter).create_node(%{node_type: :goal, title: "Pulse Goal"})
          {:ok, report} = unquote(adapter).pulse()
          assert is_map(report)
          assert is_list(report.active_goals)
          assert is_map(report.summary)
          assert report.summary.total_nodes >= 1
        end

        test "narrative_for_goal returns descendants" do
          {:ok, n1} = unquote(adapter).create_node(%{node_type: :goal, title: "Root"})
          {:ok, n2} = unquote(adapter).create_node(%{node_type: :option, title: "Child"})
          {:ok, _} = unquote(adapter).create_edge(n1.id, n2.id, :leads_to)
          {:ok, narrative} = unquote(adapter).narrative_for_goal(n1.id)
          assert length(narrative) >= 1
        end

        test "format_timeline returns string" do
          nodes = [%{inserted_at: "2026-01-01", node_type: :goal, title: "Test"}]
          result = unquote(adapter).format_timeline(nodes)
          assert is_binary(result)
          assert result =~ "Test"
        end
      end
    end
  end
end
