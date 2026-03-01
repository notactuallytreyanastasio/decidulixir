defmodule Decidulixir.Graph.ConversationNodeSet do
  @moduledoc """
  A grouping of related decision graph nodes from a single working session.

  Tracks which nodes were created or discussed together, providing
  chronological context for how work progressed.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Decidulixir.Graph.Node

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          started_at: DateTime.t(),
          ended_at: DateTime.t() | nil,
          root_node_id: integer() | nil,
          summary: String.t() | nil
        }

  schema "conversation_node_sets" do
    field :name, :string
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    belongs_to :root_node, Node, foreign_key: :root_node_id
    field :summary, :string
  end

  @required ~w(started_at)a
  @optional ~w(name ended_at root_node_id summary)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(set, attrs) do
    set
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:root_node_id)
  end
end
