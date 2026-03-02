defmodule Decidulixir.Repo.Migrations.CreateDecisionGraphTables do
  use Ecto.Migration

  def change do
    # Core graph nodes
    create table(:graph_nodes) do
      add :change_id, :uuid, null: false
      add :node_type, :string, null: false
      add :title, :text, null: false
      add :description, :text
      add :status, :string, null: false, default: "active"
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:graph_nodes, [:change_id])
    create index(:graph_nodes, [:node_type])
    create index(:graph_nodes, [:status])

    # Graph edges
    create table(:graph_edges) do
      add :from_node_id, references(:graph_nodes, on_delete: :delete_all), null: false
      add :to_node_id, references(:graph_nodes, on_delete: :delete_all), null: false
      add :from_change_id, :uuid
      add :to_change_id, :uuid
      add :edge_type, :string, null: false, default: "leads_to"
      add :weight, :float, default: 1.0
      add :rationale, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:graph_edges, [:from_node_id])
    create index(:graph_edges, [:to_node_id])
    create unique_index(:graph_edges, [:from_node_id, :to_node_id, :edge_type])

    # Conversation node sets (working sessions)
    create table(:conversation_node_sets) do
      add :name, :string
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :root_node_id, references(:graph_nodes, on_delete: :nilify_all)
      add :summary, :text
    end

    # Join table: nodes <-> conversation node sets
    create table(:conversation_node_set_nodes, primary_key: false) do
      add :conversation_node_set_id, references(:conversation_node_sets, on_delete: :delete_all),
        null: false

      add :node_id, references(:graph_nodes, on_delete: :delete_all), null: false
      add :added_at, :utc_datetime, null: false
    end

    create unique_index(:conversation_node_set_nodes, [:conversation_node_set_id, :node_id])
  end
end
