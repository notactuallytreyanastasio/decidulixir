defmodule Decidulixir.Graph.Metadata do
  @moduledoc """
  Helpers for building and extracting decision graph node metadata.

  Metadata is stored as PostgreSQL jsonb on nodes. Common keys:
  - `"confidence"` — integer 0-100
  - `"prompt"` — verbatim user prompt text
  - `"branch"` — git branch name
  - `"commit"` — git commit SHA
  - `"files"` — comma-separated associated files
  - `"agent_name"` — name of agent that created the node (Loom compat)
  """

  @type metadata :: map()

  @spec build(keyword()) :: metadata()
  def build(opts) do
    opts
    |> Enum.reduce(%{}, fn
      {:confidence, v}, acc when is_integer(v) -> Map.put(acc, "confidence", v)
      {:prompt, v}, acc when is_binary(v) -> Map.put(acc, "prompt", v)
      {:branch, v}, acc when is_binary(v) -> Map.put(acc, "branch", v)
      {:commit, v}, acc when is_binary(v) -> Map.put(acc, "commit", v)
      {:files, v}, acc when is_binary(v) -> Map.put(acc, "files", v)
      {:agent_name, v}, acc when is_binary(v) -> Map.put(acc, "agent_name", v)
      {:date, v}, acc when is_binary(v) -> Map.put(acc, "date", v)
      {k, v}, acc when is_atom(k) -> Map.put(acc, to_string(k), v)
    end)
  end

  @spec merge(metadata(), metadata()) :: metadata()
  def merge(existing, new) when is_map(existing) and is_map(new) do
    Map.merge(existing, new)
  end

  def merge(nil, new) when is_map(new), do: new
  def merge(existing, nil) when is_map(existing), do: existing

  @spec get_confidence(metadata() | nil) :: integer() | nil
  def get_confidence(nil), do: nil
  def get_confidence(metadata), do: metadata["confidence"]

  @spec get_prompt(metadata() | nil) :: String.t() | nil
  def get_prompt(nil), do: nil
  def get_prompt(metadata), do: metadata["prompt"]

  @spec get_branch(metadata() | nil) :: String.t() | nil
  def get_branch(nil), do: nil
  def get_branch(metadata), do: metadata["branch"]

  @spec get_commit(metadata() | nil) :: String.t() | nil
  def get_commit(nil), do: nil
  def get_commit(metadata), do: metadata["commit"]

  @spec get_files(metadata() | nil) :: [String.t()]
  def get_files(nil), do: []

  def get_files(metadata) do
    case metadata["files"] do
      nil -> []
      files when is_binary(files) -> String.split(files, ",", trim: true)
      files when is_list(files) -> files
    end
  end

  @spec set_confidence(metadata(), integer()) :: metadata()
  def set_confidence(metadata, confidence) when is_integer(confidence) do
    merge(metadata || %{}, %{"confidence" => confidence})
  end

  @spec set_branch(metadata(), String.t()) :: metadata()
  def set_branch(metadata, branch) when is_binary(branch) do
    merge(metadata || %{}, %{"branch" => branch})
  end

  @spec set_commit(metadata(), String.t()) :: metadata()
  def set_commit(metadata, commit) when is_binary(commit) do
    merge(metadata || %{}, %{"commit" => commit})
  end

  @spec set_prompt(metadata(), String.t()) :: metadata()
  def set_prompt(metadata, prompt) when is_binary(prompt) do
    merge(metadata || %{}, %{"prompt" => prompt})
  end
end
