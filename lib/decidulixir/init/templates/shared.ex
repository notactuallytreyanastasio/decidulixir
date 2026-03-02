defmodule Decidulixir.Init.Templates.Shared do
  @moduledoc """
  Shared template files: config, workflows, docs viewer.

  Pure data module — returns `[{path, content}]` tuples.
  """

  @doc "Returns shared infrastructure files."
  @spec files(Path.t()) :: [{String.t(), String.t()}]
  def files(_project_root) do
    [
      {".deciduous/config.toml", config_toml()},
      {"docs/graph-data.json", ~s({"nodes":[],"edges":[]})},
      {"docs/.nojekyll", ""}
    ]
  end

  @doc "Returns GitHub workflow files (only if .git exists)."
  @spec workflow_files() :: [{String.t(), String.t()}]
  def workflow_files do
    [
      {".github/workflows/cleanup-decision-graphs.yml", cleanup_workflow()},
      {".github/workflows/deploy-pages.yml", deploy_pages_workflow()}
    ]
  end

  @doc "Returns the CLAUDE.md workflow section content."
  @spec claude_md_section() :: String.t()
  def claude_md_section do
    ~S"""
    ## Decision Graph Workflow

    **THIS IS MANDATORY. Log decisions IN REAL-TIME, not retroactively.**

    ### The Core Rule

    ```
    BEFORE you do something -> Log what you're ABOUT to do
    AFTER it succeeds/fails -> Log the outcome
    CONNECT immediately -> Link every node to its parent
    ```

    ### Quick Commands

    ```bash
    mix decidulixir add goal "Title" -c 90 -p "User's original request"
    mix decidulixir add action "Title" -c 85
    mix decidulixir link FROM TO -r "reason"
    mix decidulixir nodes
    mix decidulixir show <id>
    mix decidulixir audit
    ```

    ### Behavioral Triggers

    | Trigger | Log Type |
    |---------|----------|
    | User asks for a new feature | `goal` with -p |
    | Exploring possible approaches | `option` |
    | Choosing between approaches | `decision` |
    | About to write/edit code | `action` |
    | Something worked or failed | `outcome` |
    | Notice something interesting | `observation` |
    """
  end

  defp config_toml do
    """
    # Decidulixir configuration

    [branch]
    main_branches = ["main", "master"]
    auto_detect = true
    """
  end

  defp cleanup_workflow do
    """
    name: Cleanup Decision Graphs
    on:
      pull_request:
        types: [closed]

    jobs:
      cleanup:
        if: github.event.pull_request.merged == true
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - name: Find decision graph files
            id: find
            run: |
              files=$(find docs -name "decision-graph-*.png" -o -name "decision-graph-*.dot" 2>/dev/null | tr '\\n' ' ')
              echo "files=$files" >> $GITHUB_OUTPUT
              if [ -z "$files" ]; then echo "found=false" >> $GITHUB_OUTPUT; else echo "found=true" >> $GITHUB_OUTPUT; fi
          - name: Remove graph files
            if: steps.find.outputs.found == 'true'
            run: |
              git config user.name "github-actions[bot]"
              git config user.email "github-actions[bot]@users.noreply.github.com"
              git rm ${{ steps.find.outputs.files }}
              git commit -m "chore: cleanup decision graph files from merged PR"
              git push
    """
  end

  defp deploy_pages_workflow do
    """
    name: Deploy Decision Graph to Pages
    on:
      push:
        branches: [main]
        paths: ['docs/**']

    permissions:
      contents: read
      pages: write
      id-token: write

    concurrency:
      group: "pages"
      cancel-in-progress: false

    jobs:
      deploy:
        environment:
          name: github-pages
          url: ${{ steps.deployment.outputs.page_url }}
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - uses: actions/configure-pages@v5
          - uses: actions/upload-pages-artifact@v3
            with:
              path: 'docs'
          - id: deployment
            uses: actions/deploy-pages@v4
    """
  end
end
