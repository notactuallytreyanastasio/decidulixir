defmodule Decidulixir.Graph.Edge do
  @moduledoc """
  Ecto schema for decision graph edges.

  Connects two nodes with a typed relationship and optional rationale.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Decidulixir.Graph.Node
  alias Decidulixir.Types

  @type t :: %__MODULE__{
          id: integer() | nil,
          from_node_id: integer(),
          to_node_id: integer(),
          from_change_id: Ecto.UUID.t() | nil,
          to_change_id: Ecto.UUID.t() | nil,
          edge_type: Types.edge_type(),
          weight: float() | nil,
          rationale: String.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  schema "decision_edges" do
    belongs_to :from_node, Node, foreign_key: :from_node_id
    belongs_to :to_node, Node, foreign_key: :to_node_id
    field :from_change_id, Ecto.UUID
    field :to_change_id, Ecto.UUID
    field :edge_type, Ecto.Enum, values: Types.edge_types(), default: :leads_to
    field :weight, :float, default: 1.0
    field :rationale, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required_fields ~w(from_node_id to_node_id)a
  @optional_fields ~w(from_change_id to_change_id edge_type weight rationale)a

  @doc "Changeset for creating an edge."
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(edge, attrs) do
    edge
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:edge_type, Types.edge_types())
    |> foreign_key_constraint(:from_node_id)
    |> foreign_key_constraint(:to_node_id)
    |> unique_constraint([:from_node_id, :to_node_id, :edge_type])
    |> validate_no_self_link()
  end

  defp validate_no_self_link(changeset) do
    from = get_field(changeset, :from_node_id)
    to = get_field(changeset, :to_node_id)

    if from && to && from == to do
      add_error(changeset, :to_node_id, "cannot link a node to itself")
    else
      changeset
    end
  end
end
