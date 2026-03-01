defmodule Decidulixir.Graph.Context do
  @moduledoc """
  Ecto schema for decision context records.

  Captures contextual information attached to a node (code snippets,
  environment state, etc.).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Decidulixir.Graph.Node

  @type t :: %__MODULE__{
          id: integer() | nil,
          node_id: integer(),
          context_type: String.t(),
          content_json: map(),
          captured_at: DateTime.t() | nil
        }

  schema "decision_context" do
    belongs_to :node, Node, foreign_key: :node_id
    field :context_type, :string
    field :content_json, :map, default: %{}
    field :captured_at, :utc_datetime
  end

  @required_fields ~w(node_id context_type content_json)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(context, attrs) do
    context
    |> cast(attrs, @required_fields ++ ~w(captured_at)a)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:node_id)
    |> maybe_set_captured_at()
  end

  defp maybe_set_captured_at(changeset) do
    case get_field(changeset, :captured_at) do
      nil -> put_change(changeset, :captured_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
