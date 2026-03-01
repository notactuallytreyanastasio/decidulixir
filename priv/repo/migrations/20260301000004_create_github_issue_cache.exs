defmodule Decidulixir.Repo.Migrations.CreateGithubIssues do
  use Ecto.Migration

  def change do
    create table(:github_issues) do
      add :issue_number, :integer, null: false
      add :repo, :string, null: false
      add :title, :string, null: false
      add :body, :text
      add :state, :string, null: false
      add :html_url, :string, null: false
      add :created_at, :utc_datetime
      add :updated_at, :utc_datetime
      add :cached_at, :utc_datetime, null: false
    end

    create unique_index(:github_issues, [:issue_number, :repo])
  end
end
