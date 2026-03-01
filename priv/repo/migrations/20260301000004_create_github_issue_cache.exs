defmodule Decidulixir.Repo.Migrations.CreateGithubIssueCache do
  use Ecto.Migration

  def change do
    create table(:github_issue_cache) do
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

    create unique_index(:github_issue_cache, [:issue_number, :repo])
  end
end
