defmodule Decidulixir.Init.Templates.Claude do
  @moduledoc """
  Claude Code template files.

  Pure data module — returns `[{path, content}]` tuples for all Claude Code
  integration files (slash commands, hooks, skills, agents, settings).
  """

  @behaviour Decidulixir.Init.Backend

  alias Decidulixir.Init.{FileWriter, Templates.Shared}

  @impl true
  def name, do: "Claude Code"

  @impl true
  def detect?(project_root) do
    project_root |> Path.join(".claude") |> File.dir?()
  end

  @impl true
  def files(_project_root) do
    command_files() ++ hook_files() ++ skill_files() ++ config_files()
  end

  @impl true
  def post_init(project_root) do
    claude_md_path = Path.join(project_root, "CLAUDE.md")
    section = Shared.claude_md_section()
    FileWriter.update_markdown_section(claude_md_path, section)
  end

  @doc "Returns all slash command files."
  @spec command_files() :: [{String.t(), String.t()}]
  def command_files do
    [
      {".claude/commands/decision.md", decision_md()},
      {".claude/commands/recover.md", recover_md()},
      {".claude/commands/work.md", work_md()},
      {".claude/commands/document.md", document_md()},
      {".claude/commands/build-test.md", build_test_md()},
      {".claude/commands/serve-ui.md", serve_ui_md()},
      {".claude/commands/sync-graph.md", sync_graph_md()},
      {".claude/commands/decision-graph.md", decision_graph_md()},
      {".claude/commands/sync.md", sync_md()}
    ]
  end

  @doc "Returns hook files."
  @spec hook_files() :: [{String.t(), String.t()}]
  def hook_files do
    [
      {".claude/hooks/require-action-node.sh", require_action_node_hook()},
      {".claude/hooks/post-commit-reminder.sh", post_commit_reminder_hook()}
    ]
  end

  @doc "Returns skill files."
  @spec skill_files() :: [{String.t(), String.t()}]
  def skill_files do
    [
      {".claude/skills/pulse.md", skill_pulse()},
      {".claude/skills/narratives.md", skill_narratives()},
      {".claude/skills/archaeology.md", skill_archaeology()}
    ]
  end

  @doc "Returns config files (agents.toml, settings.json)."
  @spec config_files() :: [{String.t(), String.t()}]
  def config_files do
    [
      {".claude/agents.toml", agents_toml()},
      {".claude/settings.json", settings_json()}
    ]
  end

  # --- Slash Commands ---

  defp decision_md do
    """
    # /decision — Manage Decision Graph

    Manage the decision graph for this project.

    ## Usage

    ```bash
    # Add nodes
    mix decidulixir add goal "Title" -c 90 -p "prompt"
    mix decidulixir add action "Title" -c 85
    mix decidulixir add outcome "Title"

    # Link nodes
    mix decidulixir link FROM TO -r "reason"

    # Query
    mix decidulixir nodes
    mix decidulixir edges
    mix decidulixir show <id>
    mix decidulixir audit
    ```

    ## Node Types
    - goal, decision, option, action, outcome, observation, revisit

    ## The Core Rule
    BEFORE you do something -> Log what you're ABOUT to do
    AFTER it succeeds/fails -> Log the outcome
    CONNECT immediately -> Link every node to its parent
    """
  end

  defp recover_md do
    """
    # /recover — Recover Context from Decision Graph

    Recover context from the decision graph and recent activity.

    ## Steps

    1. Check recent nodes: `mix decidulixir nodes`
    2. Check edges: `mix decidulixir edges`
    3. Check recent git: `git log --oneline -10`
    4. Check git status: `git status`
    5. Run audit: `mix decidulixir audit`

    ## Summary

    After running these commands, summarize:
    - What goals are active
    - What actions are in progress
    - Any orphan nodes or gaps
    - Current git branch and status
    """
  end

  defp work_md do
    """
    # /work — Start a Work Transaction

    Start a work transaction by creating a goal node BEFORE any implementation.

    ## Process

    1. Create a goal node capturing the user's request:
       ```bash
       mix decidulixir add goal "Title" -c 90 --prompt-stdin << 'EOF'
       <verbatim user request>
       EOF
       ```

    2. Explore options and log them:
       ```bash
       mix decidulixir add option "Approach A" -c 80
       mix decidulixir link <goal_id> <option_id> -r "possible approach"
       ```

    3. Make a decision and implement:
       ```bash
       mix decidulixir add decision "Chose approach A" -c 85
       mix decidulixir link <option_id> <decision_id> -r "best fit"
       ```

    4. Log actions and outcomes as you work.
    """
  end

  defp document_md do
    """
    # /document — Generate Documentation

    Generate comprehensive documentation for a file or directory.

    ## Usage

    Analyze the target file/directory and produce documentation covering:
    - Purpose and responsibilities
    - Public API / exports
    - Dependencies and relationships
    - Key patterns and design decisions
    - Usage examples
    """
  end

  defp build_test_md do
    """
    # /build-test — Build and Test

    Build the project and run the test suite.

    ```bash
    mix compile --warnings-as-errors && mix test
    ```

    Report results including:
    - Compilation warnings (if any)
    - Test count and failures
    - Any skipped tests
    """
  end

  defp serve_ui_md do
    """
    # /serve-ui — Start Decision Graph Viewer

    Start the Phoenix server to view the decision graph.

    ```bash
    mix phx.server
    ```

    The graph viewer will be available at http://localhost:4000/graph
    """
  end

  defp sync_graph_md do
    """
    # /sync-graph — Export Decision Graph

    Export the decision graph for GitHub Pages.

    ```bash
    mix decidulixir graph -o docs/graph-data.json
    ```

    Then commit and push the docs/ directory.
    """
  end

  defp decision_graph_md do
    """
    # /decision-graph — Build Decision Graph from History

    Build a decision graph capturing design evolution from commit history.

    ## Process

    1. Scan commits for decision-relevant changes
    2. Group into narratives
    3. Identify pivot points
    4. Build graph nodes with proper connections
    5. Validate grounding (commit SHA citations)
    """
  end

  defp sync_md do
    """
    # /sync — Multi-User Sync

    Sync the decision graph with teammates.

    For Decidulixir with PostgreSQL, the database IS the shared state.
    All users connect to the same database — no sync needed.

    If using separate databases, export and share:
    ```bash
    mix decidulixir graph -o shared-graph.json
    ```
    """
  end

  # --- Hooks ---

  defp require_action_node_hook do
    """
    #!/bin/bash
    # Require an action node before code edits
    # This hook runs before file writes to enforce decision graph discipline

    echo "Reminder: Log an action node before editing code"
    echo "  mix decidulixir add action \\"Description\\" -c 85"
    """
  end

  defp post_commit_reminder_hook do
    """
    #!/bin/bash
    # Post-commit reminder to link commits to the decision graph

    echo ""
    echo "Don't forget to link this commit to the decision graph:"
    echo "  mix decidulixir add action \\"What you just did\\" --commit HEAD"
    echo "  mix decidulixir link <goal_id> <action_id> -r \\"reason\\""
    """
  end

  # --- Skills ---

  defp skill_pulse do
    """
    # /pulse — Map Current Design as Decisions

    Take the pulse of the system — what decisions define how it works TODAY.

    ## Process

    1. Identify the area to analyze
    2. Create goal nodes for major design decisions
    3. Map options that were (or could be) considered
    4. Document the chosen decisions with rationale
    5. Note observations about the current state

    ## Output

    A decision tree showing: goal -> options -> decisions
    """
  end

  defp skill_narratives do
    """
    # /narratives — Understand Evolution

    Understand how the system evolved over time.

    ## Process

    1. Look at the current system
    2. Ask "how did this get this way?"
    3. Infer narratives from the design
    4. Find evidence (commits, PRs, docs)
    5. Identify pivots — where the approach changed

    ## Output

    Narratives tracking the evolution of key design areas.
    """
  end

  defp skill_archaeology do
    """
    # /archaeology — Structure for Query

    Transform narratives into a queryable decision graph.

    ## Mapping

    | Narrative Element | Graph Node |
    |-------------------|------------|
    | Title | goal |
    | Possible approach | option |
    | Choosing an approach | decision |
    | What was learned | observation |
    | PIVOT | revisit |

    ## Output

    Connected graph with Now <- revisit <- History links.
    """
  end

  # --- Config Files ---

  defp agents_toml do
    """
    # Decidulixir Agent Configuration

    [agents.elixir-core]
    description = "Elixir core: schemas, context, CLI"
    patterns = ["lib/decidulixir/**/*.ex", "test/decidulixir/**/*.exs"]

    [agents.web]
    description = "Phoenix LiveView: components, live views, controllers"
    patterns = ["lib/decidulixir_web/**/*.ex", "test/decidulixir_web/**/*.exs"]

    [agents.tooling]
    description = "Configuration and tooling"
    patterns = [".claude/**", "CLAUDE.md", "config/**"]
    """
  end

  defp settings_json do
    """
    {
      "hooks": {
        "pre-edit": [".claude/hooks/require-action-node.sh"],
        "post-commit": [".claude/hooks/post-commit-reminder.sh"]
      }
    }
    """
  end
end
