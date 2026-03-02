defmodule Decidulixir.Graph.GraphEdge do
  @moduledoc """
  Typed edge connecting two graph nodes with optional rationale.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Decidulixir.Graph.Node

  @edge_types ~w(leads_to requires chosen rejected blocks enables)a

  @type t :: %__MODULE__{
          id: integer() | nil,
          from_node_id: integer(),
          to_node_id: integer(),
          from_change_id: Ecto.UUID.t() | nil,
          to_change_id: Ecto.UUID.t() | nil,
          edge_type: atom(),
          weight: float() | nil,
          rationale: String.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder,
           only: [
             :id,
             :from_node_id,
             :to_node_id,
             :edge_type,
             :weight,
             :rationale,
             :inserted_at
           ]}

  schema "graph_edges" do
    belongs_to :from_node, Node, foreign_key: :from_node_id
    belongs_to :to_node, Node, foreign_key: :to_node_id
    field :from_change_id, Ecto.UUID
    field :to_change_id, Ecto.UUID
    field :edge_type, Ecto.Enum, values: @edge_types, default: :leads_to
    field :weight, :float, default: 1.0
    field :rationale, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def edge_types, do: @edge_types

  @required ~w(from_node_id to_node_id)a
  @optional ~w(from_change_id to_change_id edge_type weight rationale)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(edge, attrs) do
    edge
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
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
