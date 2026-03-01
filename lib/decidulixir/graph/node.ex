defmodule Decidulixir.Graph.Node do
  @moduledoc """
  Ecto schema for decision graph nodes.

  Maps 1:1 to the Rust `decision_nodes` table with PostgreSQL improvements:
  - `metadata_json` is native `jsonb` (queryable) instead of text
  - Timestamps are proper `utc_datetime` instead of text
  - `change_id` is a proper UUID type
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Decidulixir.Types

  @type t :: %__MODULE__{
          id: integer() | nil,
          change_id: Ecto.UUID.t(),
          node_type: Types.node_type(),
          title: String.t(),
          description: String.t() | nil,
          status: Types.node_status(),
          metadata_json: map() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "decision_nodes" do
    field :change_id, Ecto.UUID
    field :node_type, Ecto.Enum, values: Types.node_types()
    field :title, :string
    field :description, :string
    field :status, Ecto.Enum, values: Types.node_statuses(), default: :active
    field :metadata_json, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(node_type title)a
  @optional_fields ~w(description status metadata_json change_id)a

  @doc "Changeset for creating a new node."
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(node, attrs) do
    node
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:node_type, Types.node_types())
    |> validate_inclusion(:status, Types.node_statuses())
    |> maybe_generate_change_id()
  end

  @doc "Changeset for updating an existing node."
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(node, attrs) do
    node
    |> cast(attrs, ~w(title description status metadata_json)a)
    |> validate_inclusion(:status, Types.node_statuses())
  end

  defp maybe_generate_change_id(changeset) do
    case get_field(changeset, :change_id) do
      nil -> put_change(changeset, :change_id, Ecto.UUID.generate())
      _ -> changeset
    end
  end
end
