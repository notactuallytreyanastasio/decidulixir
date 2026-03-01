defmodule Decidulixir.Graph.Session do
  @moduledoc """
  Ecto schema for decision sessions.

  A session groups a set of related nodes created during a work period.
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

  schema "decision_sessions" do
    field :name, :string
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    belongs_to :root_node, Node, foreign_key: :root_node_id
    field :summary, :string
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(session, attrs) do
    session
    |> cast(attrs, ~w(name started_at ended_at root_node_id summary)a)
    |> maybe_set_started_at()
    |> foreign_key_constraint(:root_node_id)
  end

  defp maybe_set_started_at(changeset) do
    case get_field(changeset, :started_at) do
      nil -> put_change(changeset, :started_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
