defmodule Decidulixir.Graph.Document do
  @moduledoc """
  Ecto schema for file attachments on decision nodes.

  Documents are content-hash deduplicated: the same file attached to
  multiple nodes is stored once on disk.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Decidulixir.Graph.Node

  @type t :: %__MODULE__{
          id: integer() | nil,
          change_id: Ecto.UUID.t(),
          node_id: integer(),
          node_change_id: Ecto.UUID.t(),
          content_hash: String.t(),
          original_filename: String.t(),
          storage_filename: String.t(),
          mime_type: String.t(),
          file_size: integer(),
          description: String.t() | nil,
          description_source: String.t(),
          attached_at: DateTime.t(),
          attached_by: String.t() | nil,
          detached_at: DateTime.t() | nil
        }

  schema "node_documents" do
    field :change_id, Ecto.UUID
    belongs_to :node, Node, foreign_key: :node_id
    field :node_change_id, Ecto.UUID
    field :content_hash, :string
    field :original_filename, :string
    field :storage_filename, :string
    field :mime_type, :string
    field :file_size, :integer
    field :description, :string
    field :description_source, :string, default: "manual"
    field :attached_at, :utc_datetime
    field :attached_by, :string
    field :detached_at, :utc_datetime
  end

  @required_fields ~w(node_id node_change_id content_hash original_filename storage_filename mime_type file_size)a
  @optional_fields ~w(change_id description description_source attached_at attached_by detached_at)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(doc, attrs) do
    doc
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:description_source, ~w(manual ai filename))
    |> validate_number(:file_size, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:node_id)
    |> maybe_generate_change_id()
    |> maybe_set_attached_at()
  end

  defp maybe_generate_change_id(changeset) do
    case get_field(changeset, :change_id) do
      nil -> put_change(changeset, :change_id, Ecto.UUID.generate())
      _ -> changeset
    end
  end

  defp maybe_set_attached_at(changeset) do
    case get_field(changeset, :attached_at) do
      nil -> put_change(changeset, :attached_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
