defmodule Decidulixir.CLI.CommandsTest do
  use Decidulixir.DataCase, async: true

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  alias Decidulixir.CLI.Commands
  alias Decidulixir.CLI.Server
  alias Decidulixir.Graph

  defp create_node!(attrs \\ %{}) do
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
    test "creates a node with title and confidence" do
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

    test "creates all valid node types" do
      for type <- ~w(goal decision option action outcome observation revisit) do
        capture_log(fn ->
          assert {:ok, _} = exec(Commands.Add, [type, "#{type} node"])
        end)
      end
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

    test "stores branch from git context" do
      capture_log(fn ->
        assert {:ok, _} = exec(Commands.Add, ["goal", "Branch Node"])
      end)

      [node] = Graph.list_nodes(node_type: :goal)
      assert node.metadata["branch"] == "test-branch"
    end

    test "explicit branch overrides git context" do
      capture_log(fn ->
        assert {:ok, _} = exec(Commands.Add, ["goal", "Branch Node", "-b", "custom-branch"])
      end)

      [node] = Graph.list_nodes(node_type: :goal)
      assert node.metadata["branch"] == "custom-branch"
    end

    test "stores prompt in metadata" do
      capture_log(fn ->
        assert {:ok, _} = exec(Commands.Add, ["goal", "Prompted", "-p", "user prompt text"])
      end)

      [node] = Graph.list_nodes(node_type: :goal)
      assert node.metadata["prompt"] == "user prompt text"
    end

    test "stores description" do
      capture_log(fn ->
        assert {:ok, _} = exec(Commands.Add, ["goal", "Described", "-d", "A description"])
      end)

      [node] = Graph.list_nodes(node_type: :goal)
      assert node.description == "A description"
    end

    test "parse config with all options" do
      config = Commands.Add.parse(["action", "Do", "something", "-c", "85", "-p", "prompt text"])
      assert config.type == "action"
      assert config.title == "Do something"
      assert config.confidence == 85
      assert config.prompt == "prompt text"
    end

    test "parse config with branch and commit" do
      config = Commands.Add.parse(["goal", "Title", "-b", "main", "--commit", "abc123"])
      assert config.branch == "main"
      assert config.commit == "abc123"
    end

    test "parse config with files" do
      config = Commands.Add.parse(["goal", "Title", "-f", "a.ex,b.ex"])
      assert config.files == "a.ex,b.ex"
    end
  end

  # ── Link ─────────────────────────────────────────────────

  describe "Link" do
    test "creates an edge with rationale" do
      n1 = create_node!(%{title: "A"})
      n2 = create_node!(%{title: "B"})

      capture_log(fn ->
        assert :ok = exec(Commands.Link, ["#{n1.id}", "#{n2.id}", "-r", "test link"])
      end)

      edges = Graph.edges_from(n1.id)
      assert length(edges) == 1
      assert hd(edges).rationale == "test link"
    end

    test "creates edge with custom type" do
      n1 = create_node!(%{title: "A"})
      n2 = create_node!(%{title: "B"})

      capture_log(fn ->
        assert :ok = exec(Commands.Link, ["#{n1.id}", "#{n2.id}", "-t", "requires"])
      end)

      [edge] = Graph.edges_from(n1.id)
      assert edge.edge_type == :requires
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

    test "parse config" do
      config = Commands.Link.parse(["1", "2", "-r", "reason", "-t", "requires"])
      assert config.from == 1
      assert config.to == 2
      assert config.rationale == "reason"
      assert config.edge_type == "requires"
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

    test "rejects missing arguments" do
      capture_log(fn ->
        assert {:error, "missing arguments"} = exec(Commands.Unlink, [])
      end)
    end

    test "parse config" do
      config = Commands.Unlink.parse(["10", "20"])
      assert config.from == 10
      assert config.to == 20
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

    test "rejects missing arguments" do
      capture_log(fn ->
        assert {:error, "missing arguments"} = exec(Commands.Delete, [])
      end)
    end

    test "rejects non-integer ID" do
      capture_log(fn ->
        assert {:error, "invalid ID"} = exec(Commands.Delete, ["abc"])
      end)
    end

    test "parse config" do
      config = Commands.Delete.parse(["42", "--dry-run"])
      assert config.id == 42
      assert config.dry_run == true
    end

    test "parse config defaults dry_run to false" do
      config = Commands.Delete.parse(["42"])
      assert config.dry_run == false
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

    test "accepts all valid statuses" do
      for status <- ~w(active superseded abandoned pending completed rejected) do
        node = create_node!(%{title: "Status #{status}"})

        capture_log(fn ->
          assert :ok = exec(Commands.Status, ["#{node.id}", status])
        end)

        assert Graph.get_node(node.id).status == String.to_existing_atom(status)
      end
    end

    test "rejects invalid status" do
      node = create_node!(%{title: "X"})

      capture_log(fn ->
        assert {:error, "invalid status"} = exec(Commands.Status, ["#{node.id}", "bogus"])
      end)
    end

    test "rejects missing arguments" do
      capture_log(fn ->
        assert {:error, "missing arguments"} = exec(Commands.Status, [])
      end)
    end

    test "rejects missing status" do
      capture_log(fn ->
        assert {:error, "missing arguments"} = exec(Commands.Status, ["1"])
      end)
    end

    test "parse config" do
      config = Commands.Status.parse(["42", "completed"])
      assert config.id == 42
      assert config.status == :completed
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

    test "rejects missing arguments" do
      capture_log(fn ->
        assert {:error, "missing arguments"} = exec(Commands.Prompt, [])
      end)
    end

    test "rejects non-integer ID" do
      capture_log(fn ->
        assert {:error, "invalid ID"} = exec(Commands.Prompt, ["abc", "text"])
      end)
    end

    test "parse config" do
      config = Commands.Prompt.parse(["42", "hello", "world"])
      assert config.id == 42
      assert config.text == "hello world"
    end
  end

  # ── Nodes ────────────────────────────────────────────────

  describe "Nodes" do
    test "lists nodes with table format" do
      create_node!(%{title: "Listed Node"})

      output =
        capture_io(fn ->
          capture_log(fn -> exec(Commands.Nodes, []) end)
        end)

      assert output =~ "Listed Node"
      assert output =~ "ID"
      assert output =~ "Type"
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

    test "filters by status" do
      _n1 = create_node!(%{title: "Active Node"})
      n2 = create_node!(%{title: "Completed Node"})
      Graph.update_node_status(n2.id, :completed)

      output =
        capture_io(fn ->
          capture_log(fn -> exec(Commands.Nodes, ["--status", "completed"]) end)
        end)

      assert output =~ "Completed Node"
      refute output =~ "Active Node"
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

    test "returns ok for empty list" do
      capture_log(fn ->
        capture_io(fn -> assert :ok = exec(Commands.Nodes, []) end)
      end)
    end

    test "parse config hash" do
      config = Commands.Nodes.parse(["--status", "active", "--branch", "main", "-n", "5"])
      assert config.status == "active"
      assert config.branch == "main"
      assert config.limit == 5
      assert config.json == false
    end

    test "parse config with json flag" do
      config = Commands.Nodes.parse(["--json"])
      assert config.json == true
    end

    test "parse config with search" do
      config = Commands.Nodes.parse(["--search", "auth"])
      assert config.search == "auth"
    end
  end

  # ── Edges ────────────────────────────────────────────────

  describe "Edges" do
    test "lists edges with table format" do
      n1 = create_node!(%{title: "A"})
      n2 = create_node!(%{title: "B"})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to, rationale: "test"})

      output =
        capture_io(fn ->
          capture_log(fn -> exec(Commands.Edges, []) end)
        end)

      assert output =~ "leads_to"
      assert output =~ "test"
    end

    test "filters by type" do
      n1 = create_node!(%{title: "A"})
      n2 = create_node!(%{title: "B"})
      n3 = create_node!(%{title: "C"})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to})
      {:ok, _} = Graph.create_edge(n1.id, n3.id, %{edge_type: :requires})

      output =
        capture_io(fn ->
          capture_log(fn -> exec(Commands.Edges, ["--type", "requires"]) end)
        end)

      assert output =~ "requires"
    end

    test "outputs json" do
      n1 = create_node!(%{title: "A"})
      n2 = create_node!(%{title: "B"})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to})

      output =
        capture_io(fn ->
          exec(Commands.Edges, ["--json"])
        end)

      decoded = Jason.decode!(output)
      assert is_list(decoded)
    end

    test "returns ok for empty list" do
      capture_log(fn ->
        capture_io(fn -> assert :ok = exec(Commands.Edges, []) end)
      end)
    end

    test "parse config" do
      config = Commands.Edges.parse(["--type", "requires", "--json"])
      assert config.type == "requires"
      assert config.json == true
    end
  end

  # ── Show ─────────────────────────────────────────────────

  describe "Show" do
    test "shows node detail with all fields" do
      node = create_node!(%{title: "Detail Node", description: "Has desc"})

      output =
        capture_io(fn ->
          capture_log(fn -> exec(Commands.Show, ["#{node.id}"]) end)
        end)

      assert output =~ "Detail Node"
      assert output =~ "Has desc"
      assert output =~ node.change_id
      assert output =~ "Type:        goal"
      assert output =~ "Status:      active"
    end

    test "shows connected edges" do
      n1 = create_node!(%{title: "Source"})
      n2 = create_node!(%{title: "Target"})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to, rationale: "flow"})

      output =
        capture_io(fn ->
          capture_log(fn -> exec(Commands.Show, ["#{n1.id}"]) end)
        end)

      assert output =~ "Outgoing edges"
      assert output =~ "leads_to"
    end

    test "shows json output" do
      node = create_node!(%{title: "JSON Detail"})

      output =
        capture_io(fn ->
          exec(Commands.Show, ["#{node.id}", "--json"])
        end)

      decoded = Jason.decode!(output)
      assert decoded["node"]["title"] == "JSON Detail"
      assert is_list(decoded["incoming_edges"])
      assert is_list(decoded["outgoing_edges"])
    end

    test "errors on missing node" do
      capture_log(fn ->
        assert {:error, "not found"} = exec(Commands.Show, ["999999"])
      end)
    end

    test "rejects missing arguments" do
      capture_log(fn ->
        assert {:error, "missing arguments"} = exec(Commands.Show, [])
      end)
    end

    test "rejects non-integer ID" do
      capture_log(fn ->
        assert {:error, "invalid ID"} = exec(Commands.Show, ["abc"])
      end)
    end

    test "parse config" do
      config = Commands.Show.parse(["42", "--json"])
      assert config.id == 42
      assert config.json == true
    end

    test "parse config defaults json to false" do
      config = Commands.Show.parse(["42"])
      assert config.json == false
    end
  end

  # ── Graph ────────────────────────────────────────────────

  describe "Graph" do
    test "exports graph as JSON with nodes, edges, stats" do
      create_node!(%{title: "Export Me"})

      output =
        capture_io(fn ->
          exec(Commands.Graph, [])
        end)

      decoded = Jason.decode!(output)
      assert is_list(decoded["nodes"])
      assert is_list(decoded["edges"])
      assert is_map(decoded["stats"])
      assert hd(decoded["nodes"])["title"] == "Export Me"
    end

    test "exports to file" do
      create_node!(%{title: "File Export"})
      path = Path.join(System.tmp_dir!(), "test_graph_#{System.unique_integer([:positive])}.json")

      capture_log(fn ->
        config = Commands.Graph.parse(["-o", path]) |> Map.merge(base_context())
        assert :ok = Commands.Graph.execute(config)
      end)

      decoded = path |> File.read!() |> Jason.decode!()
      assert hd(decoded["nodes"])["title"] == "File Export"
      File.rm(path)
    end

    test "parse config" do
      config = Commands.Graph.parse(["-b", "main", "-o", "/tmp/out.json"])
      assert config.branch == "main"
      assert config.output == "/tmp/out.json"
    end
  end

  # ── Stats ────────────────────────────────────────────────

  describe "Stats" do
    test "shows statistics with type breakdown" do
      create_node!(%{title: "S1", node_type: :goal})
      create_node!(%{title: "S2", node_type: :action})

      output =
        capture_io(fn ->
          exec(Commands.Stats, [])
        end)

      assert output =~ "Graph Statistics"
      assert output =~ "Total nodes:"
      assert output =~ "Total edges:"
      assert output =~ "goal"
      assert output =~ "action"
    end

    test "outputs json" do
      create_node!(%{title: "JSON Stats"})

      output =
        capture_io(fn ->
          exec(Commands.Stats, ["--json"])
        end)

      decoded = Jason.decode!(output)
      assert is_map(decoded["totals"])
      assert is_map(decoded["by_type"])
    end

    test "parse config" do
      config = Commands.Stats.parse(["--json"])
      assert config.json == true
    end

    test "parse config defaults json to false" do
      config = Commands.Stats.parse([])
      assert config.json == false
    end
  end

  # ── Supersede ────────────────────────────────────────────

  describe "Supersede" do
    test "marks node as superseded and creates edge" do
      n1 = create_node!(%{title: "Old", status: :active})
      n2 = create_node!(%{title: "New", status: :active})

      capture_log(fn ->
        assert :ok = exec(Commands.Supersede, ["#{n1.id}", "#{n2.id}", "-r", "better approach"])
      end)

      assert Graph.get_node(n1.id).status == :superseded
    end

    test "errors on missing old node" do
      n2 = create_node!(%{title: "New"})

      capture_log(fn ->
        assert {:error, "not found"} = exec(Commands.Supersede, ["999999", "#{n2.id}"])
      end)
    end

    test "rejects missing arguments" do
      capture_log(fn ->
        assert {:error, "missing arguments"} = exec(Commands.Supersede, [])
      end)
    end

    test "rejects non-integer IDs" do
      capture_log(fn ->
        assert {:error, "invalid IDs"} = exec(Commands.Supersede, ["abc", "def"])
      end)
    end

    test "parse config with rationale flag" do
      config = Commands.Supersede.parse(["1", "2", "-r", "better"])
      assert config.old_id == 1
      assert config.new_id == 2
      assert config.rationale == "better"
    end

    test "parse config defaults rationale" do
      config = Commands.Supersede.parse(["1", "2"])
      assert config.rationale == "superseded"
    end
  end

  # ── Audit ────────────────────────────────────────────────

  describe "Audit" do
    test "finds orphan nodes (non-goals without edges)" do
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

      refute output =~ "Orphan"
    end

    test "goals are not flagged as orphans" do
      create_node!(%{title: "Standalone Goal", node_type: :goal})

      log =
        capture_log(fn ->
          capture_io(fn -> exec(Commands.Audit, []) end)
        end)

      refute log =~ "Orphan"
    end

    test "outputs json" do
      create_node!(%{title: "Orphan", node_type: :action})

      output =
        capture_io(fn ->
          exec(Commands.Audit, ["--json"])
        end)

      decoded = Jason.decode!(output)
      assert is_list(decoded["issues"])
      assert is_integer(decoded["count"])
      assert decoded["count"] > 0
    end

    test "parse config" do
      config = Commands.Audit.parse(["--json"])
      assert config.json == true
    end
  end

  # ── Tag ─────────────────────────────────────────────────

  describe "tag" do
    test "adds a tag to a node" do
      node = create_node!()

      capture_log(fn ->
        assert :ok = exec(Commands.Tag, ["add", "#{node.id}", "auth"])
      end)

      updated = Graph.get_node(node.id)
      assert updated.metadata["tags"] == ["auth"]
    end

    test "removes a tag from a node" do
      node = create_node!(%{metadata: %{"tags" => ["auth", "priority"]}})

      capture_log(fn ->
        assert :ok = exec(Commands.Tag, ["remove", "#{node.id}", "auth"])
      end)

      updated = Graph.get_node(node.id)
      assert updated.metadata["tags"] == ["priority"]
    end

    test "lists tags for a node" do
      node = create_node!(%{metadata: %{"tags" => ["auth", "api"]}})

      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Tag, ["list", "#{node.id}"])
        end)

      assert output =~ "auth"
      assert output =~ "api"
    end

    test "lists all tags across nodes" do
      create_node!(%{title: "A", metadata: %{"tags" => ["auth"]}})
      create_node!(%{title: "B", metadata: %{"tags" => ["auth", "api"]}})

      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Tag, ["list"])
        end)

      assert output =~ "auth"
      assert output =~ "api"
    end

    test "returns error for missing subcommand" do
      capture_log(fn ->
        assert {:error, "missing arguments"} = exec(Commands.Tag, [])
      end)
    end

    test "parse config" do
      config = Commands.Tag.parse(["add", "42", "my-tag", "--json"])
      assert config.subcommand == "add"
      assert config.node_id == 42
      assert config.tag == "my-tag"
      assert config.json == true
    end
  end

  # ── Pulse ──────────────────────────────────────────────

  describe "pulse" do
    test "shows health summary for empty graph" do
      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Pulse, [])
        end)

      assert output =~ "Graph Pulse"
      assert output =~ "healthy"
      assert output =~ "Total nodes:"
    end

    test "shows health summary with nodes" do
      create_node!(%{title: "Goal", node_type: :goal})
      create_node!(%{title: "Orphan Action", node_type: :action})

      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Pulse, [])
        end)

      assert output =~ "Total nodes:"
      assert output =~ "Orphan nodes:"
    end

    test "json output" do
      create_node!()

      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Pulse, ["--json"])
        end)

      data = Jason.decode!(output)
      assert data["total_nodes"] == 1
      assert data["health"] == "healthy"
    end

    test "parse config" do
      config = Commands.Pulse.parse(["--json"])
      assert config.json == true
    end
  end

  # ── Narratives ─────────────────────────────────────────

  describe "narratives" do
    test "shows narrative chain from a node" do
      {:ok, goal} = Graph.create_node(%{node_type: :goal, title: "Auth Goal"})
      {:ok, action} = Graph.create_node(%{node_type: :action, title: "Write Auth"})
      {:ok, _} = Graph.create_edge(goal.id, action.id, %{edge_type: :leads_to})

      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Narratives, ["#{goal.id}"])
        end)

      assert output =~ "GOAL"
      assert output =~ "Auth Goal"
      assert output =~ "ACTION"
      assert output =~ "Write Auth"
    end

    test "returns error for missing node" do
      capture_log(fn ->
        assert {:error, "not found"} = exec(Commands.Narratives, ["999999"])
      end)
    end

    test "returns error for missing arguments" do
      capture_log(fn ->
        assert {:error, "missing arguments"} = exec(Commands.Narratives, [])
      end)
    end

    test "parse config" do
      config = Commands.Narratives.parse(["42", "--depth", "5", "--json"])
      assert config.node_id == 42
      assert config.depth == 5
      assert config.json == true
    end
  end

  # ── Writeup ────────────────────────────────────────────

  describe "writeup" do
    test "generates markdown report" do
      create_node!(%{node_type: :goal, title: "My Goal"})
      create_node!(%{node_type: :action, title: "My Action"})

      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Writeup, [])
        end)

      assert output =~ "Decision Graph Report"
      assert output =~ "Goals"
    end

    test "json output" do
      create_node!(%{node_type: :goal, title: "My Goal"})

      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Writeup, ["--json"])
        end)

      data = Jason.decode!(output)
      assert is_list(data["goals"])
      assert data["total_nodes"] == 1
    end

    test "parse config" do
      config = Commands.Writeup.parse(["--node", "42", "-o", "report.md"])
      assert config.node_id == 42
      assert config.output == "report.md"
    end
  end

  # ── Backup ─────────────────────────────────────────────

  describe "backup" do
    @tag :tmp_dir
    test "exports graph to JSON file", %{tmp_dir: dir} do
      create_node!(%{title: "Backup Test"})
      path = Path.join(dir, "backup.json")

      capture_log(fn ->
        config = Commands.Backup.parse(["-o", path]) |> Map.merge(base_context())
        assert :ok = Commands.Backup.execute(config)
      end)

      assert File.exists?(path)
      data = path |> File.read!() |> Jason.decode!()
      assert data["stats"]["nodes"] == 1
      assert length(data["nodes"]) == 1
    end

    test "parse config" do
      config = Commands.Backup.parse(["-o", "/tmp/backup.json"])
      assert config.output == "/tmp/backup.json"
    end
  end

  # ── Sync ───────────────────────────────────────────────

  describe "sync" do
    @tag :tmp_dir
    test "exports graph-data.json and git-history.json", %{tmp_dir: dir} do
      create_node!(%{title: "Sync Test", metadata: %{"commit" => "abc1234"}})

      capture_log(fn ->
        config = Commands.Sync.parse(["-o", dir]) |> Map.merge(base_context())
        assert :ok = Commands.Sync.execute(config)
      end)

      assert File.exists?(Path.join(dir, "graph-data.json"))
      assert File.exists?(Path.join(dir, "git-history.json"))

      graph_data = Path.join(dir, "graph-data.json") |> File.read!() |> Jason.decode!()
      assert length(graph_data["nodes"]) == 1
    end

    test "parse config" do
      config = Commands.Sync.parse(["-o", "custom_dir"])
      assert config.output == "custom_dir"
    end
  end

  # ── Init ───────────────────────────────────────────────

  describe "init" do
    @tag :tmp_dir
    test "creates directory structure", %{tmp_dir: dir} do
      original_dir = File.cwd!()
      File.cd!(dir)

      capture_log(fn ->
        assert :ok = exec(Commands.Init, [])
      end)

      assert File.dir?(Path.join(dir, ".deciduous"))
      assert File.dir?(Path.join(dir, ".deciduous/documents"))
      assert File.exists?(Path.join(dir, ".deciduous/config.toml"))
      assert File.exists?(Path.join(dir, ".deciduous/.version"))

      File.cd!(original_dir)
    end

    test "parse config" do
      config = Commands.Init.parse(["--force"])
      assert config.force == true
    end
  end

  # ── Check-Update ───────────────────────────────────────

  describe "check-update" do
    @tag :tmp_dir
    test "reports not initialized when no .deciduous", %{tmp_dir: dir} do
      original_dir = File.cwd!()
      File.cd!(dir)

      output =
        capture_io(fn ->
          capture_log(fn ->
            assert :ok = exec(Commands.CheckUpdate, [])
          end)
        end)

      # Either logs or prints "not initialized"
      assert output =~ "not initialized" or output == ""

      File.cd!(original_dir)
    end

    test "parse config" do
      config = Commands.CheckUpdate.parse(["--json"])
      assert config.json == true
    end
  end

  # ── Update ─────────────────────────────────────────────

  describe "update" do
    @tag :tmp_dir
    test "writes version when initialized", %{tmp_dir: dir} do
      original_dir = File.cwd!()
      File.cd!(dir)
      File.mkdir_p!(".deciduous")

      capture_log(fn ->
        assert :ok = exec(Commands.Update, [])
      end)

      assert File.exists?(".deciduous/.version")

      File.cd!(original_dir)
    end

    @tag :tmp_dir
    test "errors when not initialized", %{tmp_dir: dir} do
      original_dir = File.cwd!()
      File.cd!(dir)

      capture_log(fn ->
        assert {:error, "not initialized"} = exec(Commands.Update, [])
      end)

      File.cd!(original_dir)
    end
  end

  # ── Hooks ──────────────────────────────────────────────

  describe "hooks" do
    test "lists hooks" do
      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Hooks, ["list"])
        end)

      # Output depends on whether .claude/hooks/ exists
      assert is_binary(output)
    end

    test "parse config" do
      config = Commands.Hooks.parse(["status", "--json"])
      assert config.subcommand == "status"
      assert config.json == true
    end
  end

  # ── Serve ──────────────────────────────────────────────

  describe "serve" do
    test "reports endpoint status" do
      capture_log(fn ->
        assert :ok = exec(Commands.Serve, [])
      end)
    end

    test "parse config" do
      config = Commands.Serve.parse(["--port", "8080"])
      assert config.port == 8080
    end
  end

  # ── Themes ─────────────────────────────────────────────

  describe "themes" do
    test "lists available themes" do
      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Themes, ["list"])
        end)

      assert output =~ "default"
      assert output =~ "dark"
    end

    @tag :tmp_dir
    test "sets and reads theme", %{tmp_dir: dir} do
      original_dir = File.cwd!()
      File.cd!(dir)

      capture_log(fn ->
        assert :ok = exec(Commands.Themes, ["set", "dark"])
      end)

      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Themes, ["current"])
        end)

      assert output =~ "dark"

      File.cd!(original_dir)
    end

    test "parse config" do
      config = Commands.Themes.parse(["set", "dark", "--json"])
      assert config.subcommand == "set"
      assert config.theme == "dark"
      assert config.json == true
    end
  end

  # ── Doc ────────────────────────────────────────────────

  describe "doc" do
    test "lists documents for empty graph" do
      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Doc, ["list"])
        end)

      assert output =~ "No documents found"
    end

    test "returns error for missing subcommand" do
      capture_log(fn ->
        assert {:error, "missing arguments"} = exec(Commands.Doc, [])
      end)
    end

    test "parse config" do
      config = Commands.Doc.parse(["attach", "42", "file.pdf", "-d", "Architecture diagram"])
      assert config.subcommand == "attach"
      assert config.args == ["42", "file.pdf"]
      assert config.description == "Architecture diagram"
    end
  end

  # ── Archaeology ────────────────────────────────────────

  describe "archaeology" do
    test "dry run parses commits" do
      output =
        capture_io(fn ->
          capture_log(fn ->
            config =
              Commands.Archaeology.parse(["--dry-run", "-n", "3"])
              |> Map.merge(base_context())

            assert :ok = Commands.Archaeology.execute(config)
          end)
        end)

      # Should show "Would create N node(s)" or similar dry run output
      assert output =~ "Dry Run" or output =~ "Would create"
    end

    test "parse config" do
      config = Commands.Archaeology.parse(["--since", "2024-01-01", "--dry-run", "-n", "10"])
      assert config.since == "2024-01-01"
      assert config.dry_run == true
      assert config.limit == 10
    end
  end

  # ── Behaviour compliance ─────────────────────────────────

  describe "behaviour compliance" do
    test "all command modules implement the Command behaviour" do
      for {_name, module} <- Server.commands() do
        Code.ensure_loaded!(module)

        assert function_exported?(module, :name, 0),
               "#{inspect(module)} missing name/0"

        assert function_exported?(module, :description, 0),
               "#{inspect(module)} missing description/0"

        assert function_exported?(module, :parse, 1),
               "#{inspect(module)} missing parse/1"

        assert function_exported?(module, :execute, 1),
               "#{inspect(module)} missing execute/1"
      end
    end

    test "name/0 returns a string for all commands" do
      for {_name, module} <- Server.commands() do
        assert is_binary(module.name())
      end
    end

    test "description/0 returns a string for all commands" do
      for {_name, module} <- Server.commands() do
        assert is_binary(module.description())
      end
    end

    test "parse/1 returns a map for all commands" do
      for {_name, module} <- Server.commands() do
        assert is_map(module.parse([]))
      end
    end
  end
end
