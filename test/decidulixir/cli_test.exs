defmodule Decidulixir.CLITest do
  use Decidulixir.DataCase, async: false

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  alias Decidulixir.CLI
  alias Decidulixir.Graph

  describe "execute/2" do
    test "delegates to Server and creates real nodes" do
      capture_log(fn ->
        assert :ok = CLI.execute("add", ["goal", "CLI Test"])
      end)

      [node] = Graph.list_nodes(node_type: :goal)
      assert node.title == "CLI Test"
    end

    test "returns error tuples on failure" do
      capture_log(fn ->
        assert {:error, "unknown command"} = CLI.execute("bogus", [])
      end)
    end

    test "defaults argv to empty list" do
      capture_io(fn ->
        capture_log(fn ->
          assert :ok = CLI.execute("nodes")
        end)
      end)
    end
  end

  describe "help/0" do
    test "prints usage header" do
      output = capture_io(fn -> CLI.help() end)
      assert output =~ "decidulixir"
      assert output =~ "Usage:"
      assert output =~ "mix decidulixir"
    end

    test "lists all command names" do
      output = capture_io(fn -> CLI.help() end)

      for name <-
            ~w(add link unlink delete status prompt nodes edges show graph stats supersede audit) do
        assert output =~ name, "Help output should include command '#{name}'"
      end
    end

    test "lists command descriptions" do
      output = capture_io(fn -> CLI.help() end)
      # Commands section contains descriptions alongside names
      assert output =~ "Commands:"
      assert output =~ "Add a node"
      assert output =~ "List nodes"
    end

    test "returns :ok" do
      capture_io(fn ->
        assert :ok = CLI.help()
      end)
    end
  end
end
