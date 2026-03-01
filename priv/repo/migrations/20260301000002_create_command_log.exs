defmodule Decidulixir.Repo.Migrations.CreateCommandLog do
  use Ecto.Migration

  def change do
    create table(:command_log) do
      add :command, :text, null: false
      add :description, :text
      add :working_dir, :string
      add :exit_code, :integer
      add :stdout, :text
      add :stderr, :text
      add :started_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :duration_ms, :integer
      add :decision_node_id, references(:decision_nodes, on_delete: :nilify_all)
    end

    create index(:command_log, [:started_at])
    create index(:command_log, [:decision_node_id])
  end
end
