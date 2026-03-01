defmodule Decidulixir.Repo.Migrations.CreateDocumentsAndThemes do
  use Ecto.Migration

  def change do
    # Themes
    create table(:themes) do
      add :change_id, :uuid, null: false
      add :name, :string, null: false
      add :color, :string, null: false, default: "#6366f1"
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:themes, [:name])
    create unique_index(:themes, [:change_id])

    # Node-theme associations
    create table(:node_themes, primary_key: false) do
      add :node_id, references(:decision_nodes, on_delete: :delete_all), null: false
      add :theme_id, references(:themes, on_delete: :delete_all), null: false
      add :source, :string, null: false, default: "manual"

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:node_themes, [:node_id, :theme_id])

    # Node documents (file attachments)
    create table(:node_documents) do
      add :change_id, :uuid, null: false
      add :node_id, references(:decision_nodes, on_delete: :delete_all), null: false
      add :node_change_id, :uuid, null: false
      add :content_hash, :string, null: false
      add :original_filename, :string, null: false
      add :storage_filename, :string, null: false
      add :mime_type, :string, null: false
      add :file_size, :integer, null: false
      add :description, :text
      add :description_source, :string, null: false, default: "manual"
      add :attached_at, :utc_datetime, null: false
      add :attached_by, :string
      add :detached_at, :utc_datetime
    end

    create index(:node_documents, [:node_id])
    create unique_index(:node_documents, [:change_id])
  end
end
