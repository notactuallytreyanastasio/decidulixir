defmodule Decidulixir.Graph.CommandLogTest do
  use Decidulixir.DataCase, async: true

  alias Decidulixir.Graph.{Node, CommandLog}
  alias Decidulixir.Repo

  describe "changeset/2" do
    test "valid with required fields" do
      changeset =
        CommandLog.changeset(%CommandLog{}, %{
          command: "deciduous add goal \"Test\"",
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      assert changeset.valid?
    end

    test "invalid without command" do
      changeset =
        CommandLog.changeset(%CommandLog{}, %{
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      refute changeset.valid?
      assert errors_on(changeset)[:command]
    end

    test "invalid without started_at" do
      changeset = CommandLog.changeset(%CommandLog{}, %{command: "deciduous nodes"})
      refute changeset.valid?
      assert errors_on(changeset)[:started_at]
    end

    test "accepts all optional fields" do
      node =
        %Node{}
        |> Node.changeset(%{node_type: :goal, title: "Test"})
        |> Repo.insert!()

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      changeset =
        CommandLog.changeset(%CommandLog{}, %{
          command: "deciduous add goal \"Test\"",
          description: "Added a goal",
          working_dir: "/Users/test/project",
          exit_code: 0,
          stdout: "Created node 1",
          stderr: "",
          started_at: now,
          completed_at: now,
          duration_ms: 42,
          node_id: node.id
        })

      assert changeset.valid?
    end
  end

  describe "CRUD operations" do
    test "insert and retrieve" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, log} =
        %CommandLog{}
        |> CommandLog.changeset(%{
          command: "deciduous nodes",
          started_at: now,
          exit_code: 0,
          duration_ms: 15
        })
        |> Repo.insert()

      assert log.id != nil
      fetched = Repo.get!(CommandLog, log.id)
      assert fetched.command == "deciduous nodes"
      assert fetched.exit_code == 0
    end
  end
end
