defmodule Decidulixir.CLI.Git do
  @moduledoc """
  Git operations for the CLI.

  Plain module — no process needed. Each call runs `git` via
  `System.cmd/3` in the calling process. The previous GenServer
  (`GitPort`) added unnecessary indirection for what is inherently
  a stateless, synchronous operation.
  """

  @spec cmd([String.t()]) :: {:ok, String.t()} | {:error, String.t()}
  def cmd(args) do
    case System.cmd("git", args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  @spec branch() :: String.t() | nil
  def branch do
    case cmd(["rev-parse", "--abbrev-ref", "HEAD"]) do
      {:ok, branch} -> branch
      {:error, _} -> nil
    end
  end

  @spec commit() :: String.t() | nil
  def commit do
    case cmd(["rev-parse", "--short", "HEAD"]) do
      {:ok, hash} -> hash
      {:error, _} -> nil
    end
  end
end
