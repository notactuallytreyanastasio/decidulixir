defmodule Decidulixir.Github.IssueTest do
  use Decidulixir.DataCase, async: true

  alias Decidulixir.Github.Issue
  alias Decidulixir.Repo

  @valid_attrs %{
    issue_number: 42,
    repo: "owner/repo",
    title: "Fix the thing",
    state: "open",
    html_url: "https://github.com/owner/repo/issues/42",
    cached_at: ~U[2026-03-01 00:00:00Z]
  }

  describe "changeset/2" do
    test "valid with required fields" do
      changeset = Issue.changeset(%Issue{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid without required fields" do
      changeset = Issue.changeset(%Issue{}, %{})
      refute changeset.valid?
      assert errors_on(changeset)[:issue_number]
      assert errors_on(changeset)[:repo]
      assert errors_on(changeset)[:title]
      assert errors_on(changeset)[:state]
      assert errors_on(changeset)[:html_url]
      assert errors_on(changeset)[:cached_at]
    end

    test "accepts optional body" do
      attrs = Map.put(@valid_attrs, :body, "Detailed description of the issue")
      changeset = Issue.changeset(%Issue{}, attrs)
      assert changeset.valid?
    end
  end

  describe "CRUD operations" do
    test "insert and retrieve" do
      {:ok, issue} =
        %Issue{}
        |> Issue.changeset(@valid_attrs)
        |> Repo.insert()

      assert issue.id != nil
      assert issue.issue_number == 42
      assert issue.repo == "owner/repo"

      fetched = Repo.get!(Issue, issue.id)
      assert fetched.title == "Fix the thing"
    end

    test "enforces unique constraint on issue_number + repo" do
      {:ok, _} =
        %Issue{}
        |> Issue.changeset(@valid_attrs)
        |> Repo.insert()

      {:error, changeset} =
        %Issue{}
        |> Issue.changeset(@valid_attrs)
        |> Repo.insert()

      assert errors_on(changeset)[:issue_number]
    end
  end
end
