defmodule Decidulixir.Init.Templates.Windsurf do
  @moduledoc """
  Windsurf template files.

  Pure data module — returns `[{path, content}]` tuples for Windsurf integration
  (hooks, rules).
  """

  @behaviour Decidulixir.Init.Backend

  @impl true
  def name, do: "Windsurf"

  @impl true
  def detect?(project_root) do
    project_root |> Path.join(".windsurf") |> File.dir?()
  end

  @impl true
  def files(_project_root) do
    [
      {".windsurf/hooks.json", hooks_json()},
      {".windsurf/hooks/require-action-node.sh", require_action_hook()},
      {".windsurf/hooks/post-commit-reminder.sh", post_commit_hook()},
      {".windsurf/rules/deciduous.md", rules_md()}
    ]
  end

  @impl true
  def post_init(_project_root), do: :ok

  defp hooks_json do
    """
    {
      "hooks": [
        {
          "event": "pre-write",
          "command": ".windsurf/hooks/require-action-node.sh"
        },
        {
          "event": "post-command",
          "command": ".windsurf/hooks/post-commit-reminder.sh"
        }
      ]
    }
    """
  end

  defp require_action_hook do
    """
    #!/bin/bash
    echo "Reminder: Log an action node before editing code"
    echo "  mix decidulixir add action \\"Description\\" -c 85"
    """
  end

  defp post_commit_hook do
    """
    #!/bin/bash
    echo "Link this commit to the decision graph:"
    echo "  mix decidulixir add action \\"What you did\\" --commit HEAD"
    """
  end

  defp rules_md do
    """
    # Deciduous Decision Graph Rules

    ## Always

    1. Log decisions in real-time, not retroactively
    2. Link every node to its parent immediately
    3. Use `mix decidulixir audit` to check for gaps
    4. Capture verbatim user prompts on goal nodes

    ## Node Flow

    goal -> options -> decision -> actions -> outcomes

    ## Commands

    ```bash
    mix decidulixir add goal "Title" -c 90
    mix decidulixir link FROM TO -r "reason"
    mix decidulixir nodes
    mix decidulixir audit
    ```
    """
  end
end
