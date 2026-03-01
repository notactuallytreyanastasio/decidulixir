defmodule Decidulixir.Repo.Migrations.CreateQaInteractions do
  use Ecto.Migration

  def change do
    create table(:qa_interactions) do
      add :user_prompt, :text, null: false
      add :total_prompt, :text, null: false
      add :response, :text, null: false
      add :context_json, :map
      add :inserted_at, :utc_datetime, null: false
      add :deleted_at, :utc_datetime
    end

    create index(:qa_interactions, [:inserted_at])
  end
end
