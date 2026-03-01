defmodule Decidulixir.Graph.NodeTest do
  use Decidulixir.DataCase, async: true

  alias Decidulixir.Graph.Node
  alias Decidulixir.Repo

  describe "changeset/2" do
    test "valid changeset with required fields" do
      changeset = Node.changeset(%Node{}, %{node_type: :goal, title: "Test goal"})
      assert changeset.valid?
    end

    test "generates change_id when not provided" do
      changeset = Node.changeset(%Node{}, %{node_type: :goal, title: "Test"})
      assert changeset.valid?
      change_id = Ecto.Changeset.get_field(changeset, :change_id)
      assert change_id != nil
      assert String.length(change_id) == 36
    end

    test "preserves provided change_id" do
      uuid = Ecto.UUID.generate()
      changeset = Node.changeset(%Node{}, %{node_type: :goal, title: "Test", change_id: uuid})
      assert Ecto.Changeset.get_field(changeset, :change_id) == uuid
    end

    test "invalid without title" do
      changeset = Node.changeset(%Node{}, %{node_type: :goal})
      refute changeset.valid?
      assert errors_on(changeset)[:title]
    end

    test "invalid without node_type" do
      changeset = Node.changeset(%Node{}, %{title: "No type"})
      refute changeset.valid?
      assert errors_on(changeset)[:node_type]
    end

    test "rejects invalid node_type" do
      changeset = Node.changeset(%Node{}, %{node_type: :invalid, title: "Test"})
      refute changeset.valid?
    end

    test "defaults status to active" do
      changeset = Node.changeset(%Node{}, %{node_type: :goal, title: "Test"})
      assert Ecto.Changeset.get_field(changeset, :status) == :active
    end

    test "accepts metadata_json as map" do
      meta = %{"confidence" => 90, "branch" => "main", "commit" => "abc123"}
      changeset = Node.changeset(%Node{}, %{node_type: :action, title: "Test", metadata_json: meta})
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :metadata_json) == meta
    end
  end

  describe "CRUD operations" do
    test "insert and retrieve a node" do
      {:ok, node} =
        %Node{}
        |> Node.changeset(%{node_type: :goal, title: "My goal", description: "A test goal"})
        |> Repo.insert()

      assert node.id != nil
      assert node.change_id != nil
      assert node.node_type == :goal
      assert node.title == "My goal"
      assert node.status == :active

      fetched = Repo.get!(Node, node.id)
      assert fetched.title == "My goal"
      assert fetched.change_id == node.change_id
    end

    test "insert all node types" do
      for type <- Decidulixir.Types.node_types() do
        {:ok, node} =
          %Node{}
          |> Node.changeset(%{node_type: type, title: "#{type} node"})
          |> Repo.insert()

        assert node.node_type == type
      end
    end

    test "update node status" do
      {:ok, node} =
        %Node{}
        |> Node.changeset(%{node_type: :goal, title: "Test"})
        |> Repo.insert()

      {:ok, updated} =
        node
        |> Node.update_changeset(%{status: :superseded})
        |> Repo.update()

      assert updated.status == :superseded
    end

    test "metadata_json stores and retrieves correctly" do
      meta = %{"confidence" => 85, "files" => ["lib/foo.ex", "lib/bar.ex"], "branch" => "feature"}

      {:ok, node} =
        %Node{}
        |> Node.changeset(%{node_type: :action, title: "Test", metadata_json: meta})
        |> Repo.insert()

      fetched = Repo.get!(Node, node.id)
      assert fetched.metadata_json["confidence"] == 85
      assert fetched.metadata_json["files"] == ["lib/foo.ex", "lib/bar.ex"]
    end

    test "delete a node" do
      {:ok, node} =
        %Node{}
        |> Node.changeset(%{node_type: :observation, title: "To delete"})
        |> Repo.insert()

      {:ok, _} = Repo.delete(node)
      assert Repo.get(Node, node.id) == nil
    end
  end
end
