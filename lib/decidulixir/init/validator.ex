defmodule Decidulixir.Init.Validator do
  @moduledoc """
  Pre-flight checks before initialization.

  Pure validation — no side effects.
  """

  @doc "Validate init options. Returns :ok or {:error, message}."
  @spec validate(keyword()) :: :ok | {:error, String.t()}
  def validate(opts) do
    backends = Keyword.get(opts, :backends, [])

    cond do
      backends == [] ->
        {:error, "at least one backend must be selected (--claude, --opencode, or --windsurf)"}

      true ->
        :ok
    end
  end

  @doc "Check if a project root has a .git directory."
  @spec git_repo?(Path.t()) :: boolean()
  def git_repo?(project_root) do
    project_root |> Path.join(".git") |> File.dir?()
  end

  @doc "Check if deciduous is already initialized."
  @spec initialized?(Path.t()) :: boolean()
  def initialized?(project_root) do
    project_root |> Path.join(".deciduous") |> File.dir?()
  end
end
