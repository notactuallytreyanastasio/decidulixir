defmodule Decidulixir.Repo.Migrations.CreateGraphDocuments do
  use Ecto.Migration

  def change do
    create table(:graph_documents) do
      add :change_id, :uuid, null: false
      add :node_id, references(:graph_nodes, on_delete: :delete_all), null: false
      add :node_change_id, :uuid, null: false
      add :content_hash, :string, null: false
      add :original_filename, :string, null: false
      add :storage_filename, :string, null: false
      add :storage_backend, :string, null: false, default: "local"
      add :mime_type, :string, null: false
      add :file_size, :integer, null: false
      add :description, :text
      add :description_source, :string, null: false, default: "manual"
      add :attached_at, :utc_datetime, null: false
      add :attached_by, :string
      add :detached_at, :utc_datetime
    end

    create index(:graph_documents, [:node_id])
    create unique_index(:graph_documents, [:change_id])
  end
end
