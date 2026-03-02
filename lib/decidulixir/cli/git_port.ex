defmodule Decidulixir.CLI.GitPort do
  @moduledoc """
  Deprecated — use `Decidulixir.CLI.Git` instead.

  This module previously wrapped a GenServer for git operations.
  It now delegates to the plain `Git` module for backward compatibility.
  """

  @spec cmd([String.t()]) :: {:ok, String.t()} | {:error, String.t()}
  defdelegate cmd(args), to: Decidulixir.CLI.Git
end
