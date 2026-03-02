defmodule Decidulixir.Graph.Git do
  @moduledoc """
  Git helpers for decision graph metadata.

  Delegates to the supervised GitPort for all git operations.
  """

  alias Decidulixir.CLI.GitPort

  @spec current_branch() :: {:ok, String.t()} | {:error, String.t()}
  def current_branch, do: GitPort.cmd(["rev-parse", "--abbrev-ref", "HEAD"])

  @spec current_commit() :: {:ok, String.t()} | {:error, String.t()}
  def current_commit, do: GitPort.cmd(["rev-parse", "--short", "HEAD"])

  @spec current_commit_full() :: {:ok, String.t()} | {:error, String.t()}
  def current_commit_full, do: GitPort.cmd(["rev-parse", "HEAD"])

  @spec commit_info(String.t()) :: {:ok, map()} | {:error, String.t()}
  def commit_info(sha) do
    case GitPort.cmd(["log", "-1", "--format=%H%n%s%n%an%n%aI", sha]) do
      {:ok, output} -> parse_commit_info(output)
      error -> error
    end
  end

  @spec resolve_commit(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def resolve_commit("HEAD"), do: current_commit()
  def resolve_commit(sha) when is_binary(sha), do: {:ok, sha}

  defp parse_commit_info(output) do
    case String.split(String.trim(output), "\n") do
      [full_sha, message, author, date] ->
        {:ok, %{sha: full_sha, message: message, author: author, date: date}}

      _ ->
        {:error, "unexpected git log output"}
    end
  end
end
