defmodule Decidulixir.Graph.NodeConversationNodeSet do
  @moduledoc """
  Join table linking nodes to conversation node sets.

  Records when a node was added to a particular working session.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Decidulixir.Graph.ConversationNodeSet
  alias Decidulixir.Graph.Node

  @type t :: %__MODULE__{
          conversation_node_set_id: integer(),
          node_id: integer(),
          added_at: DateTime.t()
        }

  @primary_key false
  schema "conversation_node_set_nodes" do
    belongs_to :conversation_node_set, ConversationNodeSet
    belongs_to :node, Node
    field :added_at, :utc_datetime
  end

  @required ~w(conversation_node_set_id node_id added_at)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(join, attrs) do
    join
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> foreign_key_constraint(:conversation_node_set_id)
    |> foreign_key_constraint(:node_id)
    |> unique_constraint([:conversation_node_set_id, :node_id],
      name: "conversation_node_set_nodes_conversation_node_set_id_node_id_in"
    )
  end
end
