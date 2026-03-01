defmodule Decidulixir.Graph.Git do
  @moduledoc """
  Git helpers for decision graph metadata.

  Uses `System.cmd/3` to call git. All functions return
  `{:ok, result}` or `{:error, reason}` tuples.
  """

  @doc "Returns the current git branch name."
  @spec current_branch() :: {:ok, String.t()} | {:error, String.t()}
  def current_branch do
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"], stderr_to_stdout: true) do
      {branch, 0} -> {:ok, String.trim(branch)}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc "Returns the current HEAD commit SHA (short)."
  @spec current_commit() :: {:ok, String.t()} | {:error, String.t()}
  def current_commit do
    case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> {:ok, String.trim(sha)}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc "Returns the full commit SHA for HEAD."
  @spec current_commit_full() :: {:ok, String.t()} | {:error, String.t()}
  def current_commit_full do
    case System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> {:ok, String.trim(sha)}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc """
  Returns commit info for a given SHA.

  Returns `{:ok, %{sha: ..., message: ..., author: ..., date: ...}}`.
  """
  @spec commit_info(String.t()) :: {:ok, map()} | {:error, String.t()}
  def commit_info(sha) do
    format = "%H%n%s%n%an%n%aI"

    case System.cmd("git", ["log", "-1", "--format=#{format}", sha], stderr_to_stdout: true) do
      {output, 0} ->
        case String.split(String.trim(output), "\n") do
          [full_sha, message, author, date] ->
            {:ok, %{sha: full_sha, message: message, author: author, date: date}}

          _ ->
            {:error, "unexpected git log output"}
        end

      {err, _} ->
        {:error, String.trim(err)}
    end
  end

  @doc "Resolves 'HEAD' to the actual commit SHA, or returns the input unchanged."
  @spec resolve_commit(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def resolve_commit("HEAD"), do: current_commit()
  def resolve_commit(sha) when is_binary(sha), do: {:ok, sha}
end
