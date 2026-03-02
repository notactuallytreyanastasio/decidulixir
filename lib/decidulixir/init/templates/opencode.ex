defmodule Decidulixir.Init.Templates.OpenCode do
  @moduledoc """
  OpenCode template files.

  Pure data module — returns `[{path, content}]` tuples for OpenCode integration.
  """

  @behaviour Decidulixir.Init.Backend

  @impl true
  def name, do: "OpenCode"

  @impl true
  def detect?(project_root) do
    project_root |> Path.join(".opencode") |> File.dir?()
  end

  @impl true
  def files(_project_root) do
    [
      {".opencode/commands/decision.md", decision_md()},
      {".opencode/commands/recover.md", recover_md()},
      {".opencode/commands/work.md", work_md()},
      {".opencode/commands/build-test.md", build_test_md()},
      {".opencode/opencode.json", opencode_json()}
    ]
  end

  @impl true
  def post_init(_project_root), do: :ok

  defp decision_md do
    """
    # /decision — Manage Decision Graph

    ```bash
    mix decidulixir add goal "Title" -c 90
    mix decidulixir link FROM TO -r "reason"
    mix decidulixir nodes
    mix decidulixir audit
    ```
    """
  end

  defp recover_md do
    """
    # /recover — Recover Context

    ```bash
    mix decidulixir nodes
    mix decidulixir edges
    mix decidulixir audit
    git log --oneline -10
    git status
    ```
    """
  end

  defp work_md do
    """
    # /work — Start Work Transaction

    1. `mix decidulixir add goal "Title" -c 90 -p "prompt"`
    2. Log options, decisions, actions as you work
    3. Link everything: `mix decidulixir link FROM TO -r "reason"`
    """
  end

  defp build_test_md do
    """
    # /build-test — Build and Test

    ```bash
    mix compile --warnings-as-errors && mix test
    ```
    """
  end

  defp opencode_json do
    """
    {
      "name": "decidulixir",
      "commands": {
        "decision": ".opencode/commands/decision.md",
        "recover": ".opencode/commands/recover.md",
        "work": ".opencode/commands/work.md",
        "build-test": ".opencode/commands/build-test.md"
      }
    }
    """
  end
end
