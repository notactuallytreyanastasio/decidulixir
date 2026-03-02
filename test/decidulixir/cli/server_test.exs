defmodule Decidulixir.CLI.ServerTest do
  use Decidulixir.DataCase, async: false

  import ExUnit.CaptureLog

  alias Decidulixir.CLI.Server
  alias Decidulixir.Graph

  describe "execute/2 dispatches commands" do
    test "add creates a node in the database" do
      capture_log(fn ->
        assert :ok = Server.execute("add", ["goal", "Server Test Goal", "-c", "90"])
      end)

      [node] = Graph.list_nodes(node_type: :goal)
      assert node.title == "Server Test Goal"
      assert node.metadata["confidence"] == 90
    end

    test "link creates an edge between nodes" do
      {:ok, n1} = Graph.create_node(%{node_type: :goal, title: "A"})
      {:ok, n2} = Graph.create_node(%{node_type: :action, title: "B"})

      capture_log(fn ->
        assert :ok = Server.execute("link", ["#{n1.id}", "#{n2.id}", "-r", "implements"])
      end)

      [edge] = Graph.edges_from(n1.id)
      assert edge.to_node_id == n2.id
      assert edge.rationale == "implements"
    end

    test "status updates a node in the database" do
      {:ok, node} = Graph.create_node(%{node_type: :goal, title: "To Complete"})

      capture_log(fn ->
        assert :ok = Server.execute("status", ["#{node.id}", "completed"])
      end)

      assert Graph.get_node(node.id).status == :completed
    end

    test "delete removes a node from the database" do
      {:ok, node} = Graph.create_node(%{node_type: :goal, title: "To Delete"})

      capture_log(fn ->
        assert :ok = Server.execute("delete", ["#{node.id}"])
      end)

      assert Graph.get_node(node.id) == nil
    end

    test "unlink removes edges between nodes" do
      {:ok, n1} = Graph.create_node(%{node_type: :goal, title: "A"})
      {:ok, n2} = Graph.create_node(%{node_type: :action, title: "B"})
      {:ok, _} = Graph.create_edge(n1.id, n2.id, %{edge_type: :leads_to})

      capture_log(fn ->
        assert :ok = Server.execute("unlink", ["#{n1.id}", "#{n2.id}"])
      end)

      assert Graph.edges_from(n1.id) == []
    end

    test "prompt updates node metadata" do
      {:ok, node} = Graph.create_node(%{node_type: :goal, title: "Prompt Me"})

      capture_log(fn ->
        assert :ok = Server.execute("prompt", ["#{node.id}", "full", "prompt", "text"])
      end)

      assert Graph.get_node(node.id).metadata["prompt"] == "full prompt text"
    end

    test "supersede marks old node as superseded" do
      {:ok, n1} = Graph.create_node(%{node_type: :goal, title: "Old"})
      {:ok, n2} = Graph.create_node(%{node_type: :goal, title: "New"})

      capture_log(fn ->
        assert :ok = Server.execute("supersede", ["#{n1.id}", "#{n2.id}", "-r", "better"])
      end)

      assert Graph.get_node(n1.id).status == :superseded
    end

    # IO-producing commands: verify dispatch succeeds (stdout tested in commands_test.exs)
    test "nodes dispatches successfully" do
      {:ok, _} = Graph.create_node(%{node_type: :goal, title: "Visible Node"})

      capture_log(fn ->
        assert :ok = Server.execute("nodes", [])
      end)
    end

    test "show dispatches successfully" do
      {:ok, node} = Graph.create_node(%{node_type: :goal, title: "Show Me"})

      capture_log(fn ->
        assert :ok = Server.execute("show", ["#{node.id}"])
      end)
    end

    test "stats dispatches successfully" do
      {:ok, _} = Graph.create_node(%{node_type: :goal, title: "Stat Node"})

      capture_log(fn ->
        assert :ok = Server.execute("stats", [])
      end)
    end

    test "graph dispatches successfully" do
      {:ok, _} = Graph.create_node(%{node_type: :goal, title: "Export Node"})

      capture_log(fn ->
        assert :ok = Server.execute("graph", [])
      end)
    end

    test "edges dispatches successfully" do
      capture_log(fn ->
        assert :ok = Server.execute("edges", [])
      end)
    end

    test "audit dispatches successfully on empty graph" do
      capture_log(fn ->
        assert :ok = Server.execute("audit", [])
      end)
    end

    test "returns error for unknown command" do
      capture_log(fn ->
        assert {:error, "unknown command"} = Server.execute("nonexistent", [])
      end)
    end
  end

  describe "state management" do
    test "enriches config with git context (branch metadata on created nodes)" do
      capture_log(fn ->
        assert :ok = Server.execute("add", ["goal", "Branch Test"])
      end)

      [node] = Graph.list_nodes(node_type: :goal)
      # Server enriches from GitPort — in test env we're in a real git repo
      assert is_binary(node.metadata["branch"])
    end

    test "tracks active_goal across commands" do
      capture_log(fn ->
        assert :ok = Server.execute("add", ["goal", "First Goal"])
      end)

      capture_log(fn ->
        assert :ok = Server.execute("add", ["goal", "Second Goal"])
      end)

      goals = Graph.list_nodes(node_type: :goal)
      assert length(goals) == 2
    end
  end

  describe "commands/0" do
    test "returns a map of all registered commands" do
      commands = Server.commands()
      assert is_map(commands)
      assert map_size(commands) > 0
    end

    test "includes all core commands" do
      commands = Server.commands()

      for name <-
            ~w(add link unlink delete status prompt nodes edges show graph stats supersede audit) do
        assert Map.has_key?(commands, name), "Missing command: #{name}"
      end
    end

    test "includes stub commands" do
      commands = Server.commands()

      for name <-
            ~w(doc serve sync update check-update backup pulse writeup themes tag hooks archaeology narratives) do
        assert Map.has_key?(commands, name), "Missing stub command: #{name}"
      end
    end

    test "all values are modules implementing the Command behaviour" do
      for {_name, module} <- Server.commands() do
        assert function_exported?(module, :name, 0)
        assert function_exported?(module, :description, 0)
        assert function_exported?(module, :parse, 1)
        assert function_exported?(module, :execute, 1)
      end
    end

    test "command map keys match module name/0 return values" do
      for {key, module} <- Server.commands() do
        assert module.name() == key,
               "Key '#{key}' doesn't match #{inspect(module)}.name() = '#{module.name()}'"
      end
    end
  end
end
