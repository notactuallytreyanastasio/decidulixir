defmodule Decidulixir.Graph.GraphDocument do
  @moduledoc """
  File attachment on a decision node.

  Supports pluggable storage backends. Files are content-hash
  deduplicated: the same file attached to multiple nodes is stored once.

  Storage backends:
  - `:local` (default) — files stored in `.deciduous/documents/`
  - `:s3` — files stored in configured S3 bucket (future)

  Configure via:

      config :decidulixir, :document_storage,
        backend: :local,
        path: ".deciduous/documents"
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Decidulixir.Graph.ChangesetHelpers

  alias Decidulixir.Graph.Node

  @type t :: %__MODULE__{
          id: integer() | nil,
          change_id: Ecto.UUID.t() | nil,
          node_id: integer() | nil,
          node_change_id: Ecto.UUID.t() | nil,
          content_hash: String.t() | nil,
          original_filename: String.t() | nil,
          storage_filename: String.t() | nil,
          storage_backend: String.t(),
          mime_type: String.t() | nil,
          file_size: integer() | nil,
          description: String.t() | nil,
          description_source: String.t(),
          attached_at: DateTime.t() | nil,
          attached_by: String.t() | nil,
          detached_at: DateTime.t() | nil
        }

  schema "graph_documents" do
    field :change_id, Ecto.UUID
    belongs_to :node, Node, foreign_key: :node_id
    field :node_change_id, Ecto.UUID
    field :content_hash, :string
    field :original_filename, :string
    field :storage_filename, :string
    field :storage_backend, :string, default: "local"
    field :mime_type, :string
    field :file_size, :integer
    field :description, :string
    field :description_source, :string, default: "manual"
    field :attached_at, :utc_datetime
    field :attached_by, :string
    field :detached_at, :utc_datetime
  end

  @required ~w(node_id node_change_id content_hash original_filename storage_filename mime_type file_size)a
  @optional ~w(change_id storage_backend description description_source attached_at attached_by detached_at)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(doc, attrs) do
    doc
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:description_source, ~w(manual ai filename))
    |> validate_inclusion(:storage_backend, ~w(local s3))
    |> validate_number(:file_size, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:node_id)
    |> maybe_generate_change_id()
    |> maybe_set_timestamp(:attached_at)
  end
end
