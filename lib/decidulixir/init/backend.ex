defmodule Decidulixir.Init.Backend do
  @moduledoc """
  Behaviour for AI assistant backends.

  Each backend (Claude Code, OpenCode, Windsurf) implements this behaviour,
  returning a list of `{path, content}` tuples. The init orchestrator writes
  them to disk via `FileWriter`.
  """

  @type file_entry :: {path :: String.t(), content :: String.t()}

  @doc "Human-readable backend name (e.g., \"Claude Code\")."
  @callback name() :: String.t()

  @doc "Detect whether this backend is installed in the given project root."
  @callback detect?(project_root :: Path.t()) :: boolean()

  @doc "Return all files this backend needs as `{relative_path, content}` tuples."
  @callback files(project_root :: Path.t()) :: [file_entry()]

  @doc "Run any post-init steps (e.g., appending to CLAUDE.md). Called after files are written."
  @callback post_init(project_root :: Path.t()) :: :ok | {:error, String.t()}
end
