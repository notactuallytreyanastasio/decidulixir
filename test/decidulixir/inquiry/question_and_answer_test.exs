defmodule Decidulixir.Inquiry.QuestionAndAnswerTest do
  use Decidulixir.DataCase, async: true

  alias Decidulixir.Inquiry.QuestionAndAnswer
  alias Decidulixir.Repo

  @valid_attrs %{
    user_prompt: "How does auth work?",
    total_prompt: "Context: auth system\n\nHow does auth work?",
    response: "Auth uses JWT tokens with refresh rotation.",
    inserted_at: ~U[2026-03-01 00:00:00Z]
  }

  describe "changeset/2" do
    test "valid with required fields" do
      changeset = QuestionAndAnswer.changeset(%QuestionAndAnswer{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid without required fields" do
      changeset = QuestionAndAnswer.changeset(%QuestionAndAnswer{}, %{})
      refute changeset.valid?
      assert errors_on(changeset)[:user_prompt]
      assert errors_on(changeset)[:total_prompt]
      assert errors_on(changeset)[:response]
      assert errors_on(changeset)[:inserted_at]
    end

    test "accepts optional context" do
      attrs = Map.put(@valid_attrs, :context, %{"nodes" => [1, 2, 3], "branch" => "main"})
      changeset = QuestionAndAnswer.changeset(%QuestionAndAnswer{}, attrs)
      assert changeset.valid?
    end
  end

  describe "CRUD operations" do
    test "insert and retrieve" do
      {:ok, qa} =
        %QuestionAndAnswer{}
        |> QuestionAndAnswer.changeset(@valid_attrs)
        |> Repo.insert()

      assert qa.id != nil
      fetched = Repo.get!(QuestionAndAnswer, qa.id)
      assert fetched.user_prompt == "How does auth work?"
      assert fetched.response == "Auth uses JWT tokens with refresh rotation."
    end

    test "soft delete via deleted_at" do
      {:ok, qa} =
        %QuestionAndAnswer{}
        |> QuestionAndAnswer.changeset(@valid_attrs)
        |> Repo.insert()

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, deleted} =
        qa
        |> QuestionAndAnswer.changeset(%{deleted_at: now})
        |> Repo.update()

      assert deleted.deleted_at != nil
    end
  end
end
