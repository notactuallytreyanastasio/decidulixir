defmodule Decidulixir.CLI.CommandsTest do
  use Decidulixir.DataCase, async: true

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  alias Decidulixir.CLI.Commands
  alias Decidulixir.Graph

  defp create_node!(attrs) do
    {:ok, node} = Graph.create_node(Map.merge(%{node_type: :goal, title: "Test"}, attrs))
    node
  end

  defp base_context do
    %{git_branch: "test-branch", git_commit: "abc1234", active_goal: nil}
  end

  defp exec(module, argv) do
    config = argv |> module.parse() |> Map.merge(base_context())
    module.execute(config)
  end

  # ── Add ──────────────────────────────────────────────────

  describe "Add" do
    test "creates a node" do
      capture_log(fn ->
        assert {:ok, %{active_goal: _}} = exec(Commands.Add, ["goal", "My", "Goal", "-c", "90"])
      end)

      [node] = Graph.list_nodes(node_type: :goal)
      assert node.title == "My Goal"
      assert node.metadata["confidence"] == 90
    end

    test "sets active_goal when creating a goal" do
      capture_log(fn ->
        assert {:ok, %{active_goal: id}} = exec(Commands.Add, ["goal", "New Goal"])
        assert is_integer(id)
      end)
    end

    test "returns empty updates for non-goal types" do
      capture_log(fn ->
        assert {:ok, %{}} = exec(Commands.Add, ["action", "Do stuff"])
      end)
    end

    test "rejects unknown type" do
      capture_log(fn ->
        assert {:error, "unknown type"} = exec(Commands.Add, ["unknown", "title"])
      end)
    end

    test "rejects missing title" do
      capture_log(fn ->
        assert {:error, "missing title"} = exec(Commands.Add, ["goal"])
      end)
    end

    test "rejects missing arguments" do
      capture_log(fn ->
        assert {:error, "missing arguments"} = exec(Commands.Add, [])
      end)
    end

    test "parses config with all options" do
      config = Commands.Add.parse(["action", "Do", "something", "-c", "85", "-p", "prompt text"])
      assert config.type == "action"
      assert config.title == "Do something"
      assert config.confidence == 85
      assert config.prompt == "prompt text"
    end
  end

  # ── Link ─────────────────────────────────────────────────

  describe "Link" do
    test "creates an edge" do
      n1 = create_node!(%{title: "A"})
      n2 = create_node!(%{title: "B"})

      capture_log(fn ->
        assert :ok = exec(Commands.Link, ["#{n1.id}", "#{n2.id}", "-r", "test link"])
      end)

      edges = Graph.edges_from(n1.id)
      assert length(edges) == 1
      assert hd(edges).rationale == "test link"
    end

    test "rejects non-integer IDs" do
      config = Commands.Link.parse(["abc", "def"]) |> Map.merge(base_context())

      capture_log(fn ->
        assert {:error, "invalid ID"} = Commands.Link.execute(config)
      end)
    end

    test "rejects missing arguments" do
      capture_log(fn ->
        assert {:error, "missing arguments"} = exec(Commands.Link, [])
      end)
    end

    test "shows changeset errors for invalid edge" do
      log =
        capture_log(fn ->
          assert {:error, "create edge failed"} = exec(Commands.Link, ["999", "998"])
        end)

      assert log =~ "Failed to create edge:"
    end
  end

  # ── Unlink ───────────────────────────────────────────────

  describe "Unlink" do
    test "removes an edge" do
      n1 = create_node!(%{title: "A"})
      n2 = create_node!(%{title: "B"})
      {:ok, _edge} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to})

      capture_log(fn ->
        assert :ok = exec(Commands.Unlink, ["#{n1.id}", "#{n2.id}"])
      end)

      assert Graph.edges_from(n1.id) == []
    end

    test "warns when no edge exists" do
      n1 = create_node!(%{title: "A"})
      n2 = create_node!(%{title: "B"})

      log =
        capture_log(fn ->
          assert :ok = exec(Commands.Unlink, ["#{n1.id}", "#{n2.id}"])
        end)

      assert log =~ "No edges found"
    end
  end

  # ── Delete ───────────────────────────────────────────────

  describe "Delete" do
    test "deletes a node" do
      node = create_node!(%{title: "To Delete"})

      capture_log(fn ->
        assert :ok = exec(Commands.Delete, ["#{node.id}"])
      end)

      assert Graph.get_node(node.id) == nil
    end

    test "supports dry run" do
      node = create_node!(%{title: "Keep Me"})

      capture_log(fn ->
        assert :ok = exec(Commands.Delete, ["#{node.id}", "--dry-run"])
      end)

      assert Graph.get_node(node.id) != nil
    end

    test "errors on missing node" do
      capture_log(fn ->
        assert {:error, "not found"} = exec(Commands.Delete, ["999999"])
      end)
    end
  end

  # ── Status ───────────────────────────────────────────────

  describe "Status" do
    test "updates node status" do
      node = create_node!(%{title: "Active"})

      capture_log(fn ->
        assert :ok = exec(Commands.Status, ["#{node.id}", "completed"])
      end)

      assert Graph.get_node(node.id).status == :completed
    end

    test "rejects invalid status" do
      node = create_node!(%{title: "X"})

      capture_log(fn ->
        assert {:error, "invalid status"} = exec(Commands.Status, ["#{node.id}", "bogus"])
      end)
    end
  end

  # ── Prompt ───────────────────────────────────────────────

  describe "Prompt" do
    test "sets prompt on node" do
      node = create_node!(%{title: "Needs Prompt"})

      capture_log(fn ->
        assert :ok = exec(Commands.Prompt, ["#{node.id}", "full", "verbatim", "prompt"])
      end)

      updated = Graph.get_node(node.id)
      assert updated.metadata["prompt"] == "full verbatim prompt"
    end

    test "rejects empty prompt" do
      capture_log(fn ->
        assert {:error, "missing prompt"} = exec(Commands.Prompt, ["1"])
      end)
    end
  end

  # ── Nodes ────────────────────────────────────────────────

  describe "Nodes" do
    test "lists nodes" do
      create_node!(%{title: "Listed Node"})

      output =
        capture_io(fn ->
          capture_log(fn -> exec(Commands.Nodes, []) end)
        end)

      assert output =~ "Listed Node"
    end

    test "filters by type" do
      create_node!(%{title: "Goal One", node_type: :goal})
      create_node!(%{title: "Action One", node_type: :action})

      output =
        capture_io(fn ->
          capture_log(fn -> exec(Commands.Nodes, ["--type", "action"]) end)
        end)

      assert output =~ "Action One"
      refute output =~ "Goal One"
    end

    test "outputs json" do
      create_node!(%{title: "JSON Node"})

      output =
        capture_io(fn ->
          exec(Commands.Nodes, ["--json"])
        end)

      decoded = Jason.decode!(output)
      assert is_list(decoded)
      assert hd(decoded)["title"] == "JSON Node"
    end

    test "parses config hash" do
      config = Commands.Nodes.parse(["--status", "active", "--branch", "main", "-n", "5"])
      assert config.status == "active"
      assert config.branch == "main"
      assert config.limit == 5
      assert config.json == false
    end
  end

  # ── Edges ────────────────────────────────────────────────

  describe "Edges" do
    test "lists edges" do
      n1 = create_node!(%{title: "A"})
      n2 = create_node!(%{title: "B"})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to, rationale: "test"})

      output =
        capture_io(fn ->
          capture_log(fn -> exec(Commands.Edges, []) end)
        end)

      assert output =~ "leads_to"
    end
  end

  # ── Show ─────────────────────────────────────────────────

  describe "Show" do
    test "shows node detail" do
      node = create_node!(%{title: "Detail Node", description: "Has desc"})

      output =
        capture_io(fn ->
          capture_log(fn -> exec(Commands.Show, ["#{node.id}"]) end)
        end)

      assert output =~ "Detail Node"
      assert output =~ "Has desc"
      assert output =~ node.change_id
    end

    test "shows json output" do
      node = create_node!(%{title: "JSON Detail"})

      output =
        capture_io(fn ->
          exec(Commands.Show, ["#{node.id}", "--json"])
        end)

      decoded = Jason.decode!(output)
      assert decoded["node"]["title"] == "JSON Detail"
    end

    test "errors on missing node" do
      capture_log(fn ->
        assert {:error, "not found"} = exec(Commands.Show, ["999999"])
      end)
    end
  end

  # ── Graph ────────────────────────────────────────────────

  describe "Graph" do
    test "exports graph as JSON" do
      create_node!(%{title: "Export Me"})

      output =
        capture_io(fn ->
          exec(Commands.Graph, [])
        end)

      decoded = Jason.decode!(output)
      assert is_list(decoded["nodes"])
      assert is_list(decoded["edges"])
    end
  end

  # ── Stats ────────────────────────────────────────────────

  describe "Stats" do
    test "shows statistics" do
      create_node!(%{title: "S1", node_type: :goal})
      create_node!(%{title: "S2", node_type: :action})

      output =
        capture_io(fn ->
          exec(Commands.Stats, [])
        end)

      assert output =~ "Total nodes:"
      assert output =~ "goal"
    end
  end

  # ── Supersede ────────────────────────────────────────────

  describe "Supersede" do
    test "marks node as superseded" do
      n1 = create_node!(%{title: "Old", status: :active})
      n2 = create_node!(%{title: "New", status: :active})

      capture_log(fn ->
        assert :ok = exec(Commands.Supersede, ["#{n1.id}", "#{n2.id}", "-r", "better approach"])
      end)

      assert Graph.get_node(n1.id).status == :superseded
    end
  end

  # ── Audit ────────────────────────────────────────────────

  describe "Audit" do
    test "finds orphan nodes" do
      create_node!(%{title: "Root Goal", node_type: :goal})
      create_node!(%{title: "Orphan Action", node_type: :action})

      log =
        capture_log(fn ->
          capture_io(fn -> exec(Commands.Audit, []) end)
        end)

      assert log =~ "Orphan"
      assert log =~ "Orphan Action"
    end

    test "reports clean graph" do
      output =
        capture_io(fn ->
          capture_log(fn -> assert :ok = exec(Commands.Audit, []) end)
        end)

      # No issues output to stdout
      refute output =~ "Orphan"
    end
  end
end
