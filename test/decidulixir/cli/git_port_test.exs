defmodule Decidulixir.CLI.GitPortTest do
  use ExUnit.Case, async: false

  alias Decidulixir.CLI.GitPort

  @moduletag :tmp_dir

  describe "cmd/1 against real git repo" do
    setup %{tmp_dir: tmp_dir} do
      # Create a real git repo in the temp dir
      System.cmd("git", ["init", tmp_dir])
      System.cmd("git", ["-C", tmp_dir, "config", "user.email", "test@test.com"])
      System.cmd("git", ["-C", tmp_dir, "config", "user.name", "Test"])

      # Create a file and commit
      File.write!(Path.join(tmp_dir, "README.md"), "# Test Repo\n")
      System.cmd("git", ["-C", tmp_dir, "add", "README.md"])
      System.cmd("git", ["-C", tmp_dir, "commit", "-m", "initial commit"])

      %{repo: tmp_dir}
    end

    test "rev-parse HEAD returns a commit hash", %{repo: repo} do
      assert {:ok, hash} = GitPort.cmd(["-C", repo, "rev-parse", "--short", "HEAD"])
      # Short hash is 7+ hex chars
      assert Regex.match?(~r/^[0-9a-f]{7,}$/, hash)
    end

    test "rev-parse --abbrev-ref HEAD returns branch name", %{repo: repo} do
      assert {:ok, branch} = GitPort.cmd(["-C", repo, "rev-parse", "--abbrev-ref", "HEAD"])
      assert branch in ["main", "master"]
    end

    test "log returns commit messages", %{repo: repo} do
      assert {:ok, log} = GitPort.cmd(["-C", repo, "log", "--oneline", "-1"])
      assert log =~ "initial commit"
    end

    test "status returns clean status", %{repo: repo} do
      assert {:ok, status} = GitPort.cmd(["-C", repo, "status", "--porcelain"])
      assert status == ""
    end

    test "status shows untracked files", %{repo: repo} do
      File.write!(Path.join(repo, "new_file.txt"), "content")
      assert {:ok, status} = GitPort.cmd(["-C", repo, "status", "--porcelain"])
      assert status =~ "new_file.txt"
    end

    test "returns error for invalid command" do
      assert {:error, msg} = GitPort.cmd(["not-a-real-command"])
      assert is_binary(msg)
    end

    test "returns error for invalid repo path" do
      assert {:error, _} = GitPort.cmd(["-C", "/nonexistent/path", "status"])
    end

    test "diff returns empty for clean repo", %{repo: repo} do
      assert {:ok, diff} = GitPort.cmd(["-C", repo, "diff"])
      assert diff == ""
    end

    test "diff shows changes after modification", %{repo: repo} do
      readme = Path.join(repo, "README.md")
      File.write!(readme, "# Modified\n")
      assert {:ok, diff} = GitPort.cmd(["-C", repo, "diff"])
      assert diff =~ "Modified"
    end

    test "branch operations work", %{repo: repo} do
      System.cmd("git", ["-C", repo, "checkout", "-b", "test-branch"])
      assert {:ok, branch} = GitPort.cmd(["-C", repo, "rev-parse", "--abbrev-ref", "HEAD"])
      assert branch == "test-branch"
    end
  end

  describe "cmd/1 against project repo" do
    test "returns current branch" do
      assert {:ok, branch} = GitPort.cmd(["rev-parse", "--abbrev-ref", "HEAD"])
      assert is_binary(branch)
      assert String.length(branch) > 0
    end

    test "returns current short commit" do
      assert {:ok, hash} = GitPort.cmd(["rev-parse", "--short", "HEAD"])
      assert Regex.match?(~r/^[0-9a-f]+$/, hash)
    end
  end
end
