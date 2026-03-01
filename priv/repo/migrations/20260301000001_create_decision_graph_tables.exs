defmodule Decidulixir.Repo.Migrations.CreateDecisionGraphTables do
  use Ecto.Migration

  def change do
    # Core decision nodes
    create table(:decision_nodes) do
      add :change_id, :uuid, null: false
      add :node_type, :string, null: false
      add :title, :text, null: false
      add :description, :text
      add :status, :string, null: false, default: "active"
      add :metadata_json, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:decision_nodes, [:change_id])
    create index(:decision_nodes, [:node_type])
    create index(:decision_nodes, [:status])

    # Decision edges
    create table(:decision_edges) do
      add :from_node_id, references(:decision_nodes, on_delete: :delete_all), null: false
      add :to_node_id, references(:decision_nodes, on_delete: :delete_all), null: false
      add :from_change_id, :uuid
      add :to_change_id, :uuid
      add :edge_type, :string, null: false, default: "leads_to"
      add :weight, :float, default: 1.0
      add :rationale, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:decision_edges, [:from_node_id])
    create index(:decision_edges, [:to_node_id])
    create unique_index(:decision_edges, [:from_node_id, :to_node_id, :edge_type])

    # Decision context
    create table(:decision_context) do
      add :node_id, references(:decision_nodes, on_delete: :delete_all), null: false
      add :context_type, :string, null: false
      add :content_json, :map, null: false, default: %{}
      add :captured_at, :utc_datetime, null: false
    end

    create index(:decision_context, [:node_id])

    # Sessions
    create table(:decision_sessions) do
      add :name, :string
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :root_node_id, references(:decision_nodes, on_delete: :nilify_all)
      add :summary, :text
    end

    # Session-node join table
    create table(:session_nodes, primary_key: false) do
      add :session_id, references(:decision_sessions, on_delete: :delete_all), null: false
      add :node_id, references(:decision_nodes, on_delete: :delete_all), null: false
      add :added_at, :utc_datetime, null: false
    end

    create unique_index(:session_nodes, [:session_id, :node_id])
  end
end
