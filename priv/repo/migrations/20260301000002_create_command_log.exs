defmodule Decidulixir.Repo.Migrations.CreateCommandLog do
  use Ecto.Migration

  def change do
    create table(:graph_commands) do
      add :command, :text, null: false
      add :description, :text
      add :working_dir, :string
      add :exit_code, :integer
      add :stdout, :text
      add :stderr, :text
      add :started_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :duration_ms, :integer
      add :node_id, references(:graph_nodes, on_delete: :nilify_all)
    end

    create index(:graph_commands, [:started_at])
    create index(:graph_commands, [:node_id])
  end
end
