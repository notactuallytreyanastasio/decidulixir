defmodule Decidulixir.CLI.ServerTest do
  use Decidulixir.DataCase, async: false

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  alias Decidulixir.CLI.Server

  describe "execute/2" do
    test "dispatches to add command" do
      capture_log(fn ->
        assert :ok = Server.execute("add", ["goal", "Test Goal", "-c", "90"])
      end)
    end

    test "returns error for unknown command" do
      capture_log(fn ->
        assert {:error, "unknown command"} = Server.execute("nonexistent", [])
      end)
    end

    test "dispatches to nodes command" do
      capture_io(fn ->
        capture_log(fn ->
          assert :ok = Server.execute("nodes", [])
        end)
      end)
    end
  end

  describe "commands/0" do
    test "lists all registered commands" do
      commands = Server.commands()
      assert Map.has_key?(commands, "add")
      assert Map.has_key?(commands, "nodes")
      assert Map.has_key?(commands, "audit")
      assert Map.has_key?(commands, "link")
      assert Map.has_key?(commands, "doc")
      assert Map.has_key?(commands, "archaeology")
    end
  end
end
