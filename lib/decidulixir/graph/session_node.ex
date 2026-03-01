defmodule Decidulixir.Graph.SessionNode do
  @moduledoc """
  Join table linking sessions to their constituent nodes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Decidulixir.Graph.{Node, Session}

  @type t :: %__MODULE__{
          session_id: integer(),
          node_id: integer(),
          added_at: DateTime.t()
        }

  @primary_key false
  schema "session_nodes" do
    belongs_to :session, Session
    belongs_to :node, Node
    field :added_at, :utc_datetime
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(session_node, attrs) do
    session_node
    |> cast(attrs, ~w(session_id node_id added_at)a)
    |> validate_required(~w(session_id node_id)a)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:node_id)
    |> maybe_set_added_at()
  end

  defp maybe_set_added_at(changeset) do
    case get_field(changeset, :added_at) do
      nil -> put_change(changeset, :added_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
