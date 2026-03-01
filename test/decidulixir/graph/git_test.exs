defmodule Decidulixir.Graph.GitTest do
  use ExUnit.Case, async: true

  alias Decidulixir.Graph.Git

  describe "current_branch/0" do
    test "returns a branch name" do
      {:ok, branch} = Git.current_branch()
      assert is_binary(branch)
      assert String.length(branch) > 0
    end
  end

  describe "current_commit/0" do
    test "returns a short SHA" do
      {:ok, sha} = Git.current_commit()
      assert is_binary(sha)
      assert String.length(sha) >= 7
    end
  end

  describe "current_commit_full/0" do
    test "returns a 40-char SHA" do
      {:ok, sha} = Git.current_commit_full()
      assert String.length(sha) == 40
    end
  end

  describe "commit_info/1" do
    test "returns info for HEAD" do
      {:ok, sha} = Git.current_commit()
      {:ok, info} = Git.commit_info(sha)
      assert is_binary(info.sha)
      assert is_binary(info.message)
      assert is_binary(info.author)
      assert is_binary(info.date)
    end
  end

  describe "resolve_commit/1" do
    test "resolves HEAD to a SHA" do
      {:ok, sha} = Git.resolve_commit("HEAD")
      assert is_binary(sha)
      assert String.length(sha) >= 7
    end

    test "passes through regular SHA" do
      assert Git.resolve_commit("abc123") == {:ok, "abc123"}
    end
  end
end
