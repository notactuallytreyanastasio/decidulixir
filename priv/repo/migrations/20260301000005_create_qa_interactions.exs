defmodule Decidulixir.Repo.Migrations.CreateQuestionsAndAnswers do
  use Ecto.Migration

  def change do
    create table(:questions_and_answers) do
      add :user_prompt, :text, null: false
      add :total_prompt, :text, null: false
      add :response, :text, null: false
      add :context, :map
      add :inserted_at, :utc_datetime, null: false
      add :deleted_at, :utc_datetime
    end

    create index(:questions_and_answers, [:inserted_at])
  end
end
