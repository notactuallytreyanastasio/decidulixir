defmodule Decidulixir.Graph.ConversationNodeSetTest do
  use Decidulixir.DataCase, async: true

  alias Decidulixir.Graph.ConversationNodeSet
  alias Decidulixir.Graph.Node
  alias Decidulixir.Graph.NodeConversationNodeSet
  alias Decidulixir.Repo

  defp create_node!(attrs \\ %{}) do
    %Node{}
    |> Node.changeset(Map.merge(%{node_type: :goal, title: "Test node"}, attrs))
    |> Repo.insert!()
  end

  describe "ConversationNodeSet changeset/2" do
    test "valid with started_at" do
      changeset =
        ConversationNodeSet.changeset(%ConversationNodeSet{}, %{
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      assert changeset.valid?
    end

    test "invalid without started_at" do
      changeset = ConversationNodeSet.changeset(%ConversationNodeSet{}, %{})
      refute changeset.valid?
      assert errors_on(changeset)[:started_at]
    end

    test "accepts optional fields" do
      node = create_node!()

      changeset =
        ConversationNodeSet.changeset(%ConversationNodeSet{}, %{
          name: "Morning session",
          started_at: DateTime.utc_now() |> DateTime.truncate(:second),
          root_node_id: node.id,
          summary: "Worked on auth"
        })

      assert changeset.valid?
    end
  end

  describe "ConversationNodeSet CRUD" do
    test "insert and retrieve" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, set} =
        %ConversationNodeSet{}
        |> ConversationNodeSet.changeset(%{name: "Session 1", started_at: now})
        |> Repo.insert()

      assert set.id != nil
      assert set.name == "Session 1"

      fetched = Repo.get!(ConversationNodeSet, set.id)
      assert fetched.name == "Session 1"
    end
  end

  describe "NodeConversationNodeSet (join table)" do
    test "links a node to a conversation set" do
      node = create_node!()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, set} =
        %ConversationNodeSet{}
        |> ConversationNodeSet.changeset(%{started_at: now})
        |> Repo.insert()

      {:ok, join} =
        %NodeConversationNodeSet{}
        |> NodeConversationNodeSet.changeset(%{
          conversation_node_set_id: set.id,
          node_id: node.id,
          added_at: now
        })
        |> Repo.insert()

      assert join.conversation_node_set_id == set.id
      assert join.node_id == node.id
    end

    test "enforces unique constraint on set + node" do
      node = create_node!()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, set} =
        %ConversationNodeSet{}
        |> ConversationNodeSet.changeset(%{started_at: now})
        |> Repo.insert()

      {:ok, _} =
        %NodeConversationNodeSet{}
        |> NodeConversationNodeSet.changeset(%{
          conversation_node_set_id: set.id,
          node_id: node.id,
          added_at: now
        })
        |> Repo.insert()

      {:error, changeset} =
        %NodeConversationNodeSet{}
        |> NodeConversationNodeSet.changeset(%{
          conversation_node_set_id: set.id,
          node_id: node.id,
          added_at: now
        })
        |> Repo.insert()

      assert errors_on(changeset)[:conversation_node_set_id]
    end
  end
end
