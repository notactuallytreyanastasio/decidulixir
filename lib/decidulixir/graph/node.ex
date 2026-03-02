defmodule Decidulixir.Graph.Node do
  @moduledoc """
  Decision graph node. The core entity — goals, decisions, options,
  actions, outcomes, observations, and revisit nodes.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Decidulixir.Graph.ChangesetHelpers

  @node_types ~w(goal decision option action outcome observation revisit)a
  @node_statuses ~w(active superseded abandoned pending completed rejected)a

  @type t :: %__MODULE__{
          id: integer() | nil,
          change_id: Ecto.UUID.t(),
          node_type: atom(),
          title: String.t(),
          description: String.t() | nil,
          status: atom(),
          metadata: map() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder,
           only: [
             :id,
             :change_id,
             :node_type,
             :title,
             :description,
             :status,
             :metadata,
             :inserted_at,
             :updated_at
           ]}

  schema "graph_nodes" do
    field :change_id, Ecto.UUID
    field :node_type, Ecto.Enum, values: @node_types
    field :title, :string
    field :description, :string
    field :status, Ecto.Enum, values: @node_statuses, default: :active
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def node_types, do: @node_types
  def node_statuses, do: @node_statuses

  @required ~w(node_type title)a
  @optional ~w(description status metadata change_id)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(node, attrs) do
    node
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> maybe_generate_change_id()
  end

  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(node, attrs) do
    cast(node, attrs, ~w(title description status metadata)a)
  end
end
