defmodule Decidulixir.CLI.IntegrationTest do
  @moduledoc """
  Integration tests exercising full CLI workflows against real git repos,
  real database operations, and real command execution. No mocks except Claude AI.
  """
  use Decidulixir.DataCase, async: false

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  alias Decidulixir.CLI.Commands
  alias Decidulixir.Graph

  @moduletag :tmp_dir

  # ── Test Helpers ───────────────────────────────────────

  defp git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end

  defp git_sha(dir), do: git!(dir, ["rev-parse", "--short", "HEAD"])

  defp context(repo, active_goal \\ nil) do
    %{
      git_branch: git!(repo, ["rev-parse", "--abbrev-ref", "HEAD"]),
      git_commit: git_sha(repo),
      active_goal: active_goal
    }
  end

  defp exec(module, argv, ctx) do
    config = argv |> module.parse() |> Map.merge(ctx)
    module.execute(config)
  end

  defp write_code!(dir, rel_path, content) do
    full = Path.join(dir, rel_path)
    full |> Path.dirname() |> File.mkdir_p!()
    File.write!(full, content)
    rel_path
  end

  defp commit!(dir, files, message) do
    Enum.each(files, fn f -> git!(dir, ["add", f]) end)
    git!(dir, ["commit", "-m", message])
    git_sha(dir)
  end

  # ── Setup ──────────────────────────────────────────────

  setup %{tmp_dir: tmp_dir} do
    # Create a real git repo with real Elixir code
    git!(tmp_dir, ["init", "--initial-branch", "main"])
    git!(tmp_dir, ["config", "user.email", "dev@example.com"])
    git!(tmp_dir, ["config", "user.name", "Test Developer"])

    # Write initial code and commit
    write_code!(tmp_dir, "lib/app.ex", """
    defmodule App do
      @moduledoc "Main application module."
      def hello, do: "world"
    end
    """)

    write_code!(tmp_dir, "mix.exs", """
    defmodule App.MixProject do
      use Mix.Project
      def project, do: [app: :app, version: "0.1.0"]
    end
    """)

    initial_sha = commit!(tmp_dir, ["lib/app.ex", "mix.exs"], "feat: initial app module")

    %{repo: tmp_dir, initial_sha: initial_sha}
  end

  # ── Full Decision Workflow ─────────────────────────────

  describe "full decision workflow" do
    test "goal → options → decision → action → outcome with real git commits", %{repo: repo} do
      ctx = context(repo)

      # 1. Create a goal
      capture_log(fn ->
        assert {:ok, %{active_goal: goal_id}} =
                 exec(Commands.Add, ["goal", "Add user authentication", "-c", "90"], ctx)

        assert is_integer(goal_id)
      end)

      [goal] = Graph.list_nodes(node_type: :goal)
      assert goal.title == "Add user authentication"
      assert goal.metadata["confidence"] == 90
      assert goal.metadata["branch"] == "main"

      ctx = %{ctx | active_goal: goal.id}

      # 2. Create options
      capture_log(fn ->
        assert {:ok, _} = exec(Commands.Add, ["option", "JWT tokens"], ctx)
        assert {:ok, _} = exec(Commands.Add, ["option", "Session cookies"], ctx)
      end)

      options = Graph.list_nodes(node_type: :option)
      assert length(options) == 2

      # 3. Link options to goal
      jwt_opt = Enum.find(options, &(&1.title == "JWT tokens"))
      session_opt = Enum.find(options, &(&1.title == "Session cookies"))

      capture_log(fn ->
        assert :ok =
                 exec(Commands.Link, ["#{goal.id}", "#{jwt_opt.id}", "-r", "explore JWT"], ctx)

        assert :ok =
                 exec(
                   Commands.Link,
                   ["#{goal.id}", "#{session_opt.id}", "-r", "explore sessions"],
                   ctx
                 )
      end)

      assert length(Graph.edges_from(goal.id)) == 2

      # 4. Make a decision
      capture_log(fn ->
        assert {:ok, _} = exec(Commands.Add, ["decision", "Use JWT for stateless auth"], ctx)
      end)

      [decision] = Graph.list_nodes(node_type: :decision)

      capture_log(fn ->
        assert :ok =
                 exec(Commands.Link, ["#{jwt_opt.id}", "#{decision.id}", "-r", "chosen"], ctx)
      end)

      # 5. Write real auth code, make a real commit
      write_code!(repo, "lib/auth.ex", """
      defmodule Auth do
        @moduledoc "JWT authentication module."
        def verify(token), do: {:ok, token}
        def sign(payload), do: "jwt_" <> inspect(payload)
      end
      """)

      write_code!(repo, "lib/auth/token.ex", """
      defmodule Auth.Token do
        @moduledoc "Token generation and validation."
        def generate(user_id), do: "token_\#{user_id}"
      end
      """)

      auth_sha = commit!(repo, ["lib/auth.ex", "lib/auth/token.ex"], "feat: add JWT auth module")
      ctx_after_commit = context(repo, goal.id)

      # 6. Create action linked to the commit
      capture_log(fn ->
        assert {:ok, _} =
                 exec(
                   Commands.Add,
                   ["action", "Implemented JWT auth", "--commit", auth_sha],
                   ctx_after_commit
                 )
      end)

      [action] = Graph.list_nodes(node_type: :action)
      assert action.metadata["commit"] == auth_sha

      capture_log(fn ->
        assert :ok =
                 exec(
                   Commands.Link,
                   ["#{decision.id}", "#{action.id}", "-r", "implementation"],
                   ctx_after_commit
                 )
      end)

      # 7. Create outcome
      capture_log(fn ->
        assert {:ok, _} = exec(Commands.Add, ["outcome", "JWT auth working, tests pass"], ctx)
      end)

      [outcome] = Graph.list_nodes(node_type: :outcome)

      capture_log(fn ->
        assert :ok =
                 exec(
                   Commands.Link,
                   ["#{action.id}", "#{outcome.id}", "-r", "result"],
                   ctx
                 )
      end)

      # 8. Verify full graph
      all_nodes = Graph.list_nodes()
      all_edges = Graph.list_edges()
      assert length(all_nodes) == 6
      assert length(all_edges) == 5

      # 9. Audit — no orphans since everything is linked
      output =
        capture_io(fn ->
          capture_log(fn ->
            assert :ok = exec(Commands.Audit, [], ctx)
          end)
        end)

      refute output =~ "Orphan"

      # 10. Pulse — health check
      pulse_output =
        capture_io(fn ->
          assert :ok = exec(Commands.Pulse, ["--json"], ctx)
        end)

      pulse = Jason.decode!(pulse_output)
      assert pulse["total_nodes"] == 6
      assert pulse["total_edges"] == 5
      assert pulse["health"] == "healthy"

      # 11. Narratives — follow the chain from goal
      narrative_output =
        capture_io(fn ->
          assert :ok = exec(Commands.Narratives, ["#{goal.id}", "--json"], ctx)
        end)

      chain = Jason.decode!(narrative_output)
      assert length(chain) >= 3
      types = Enum.map(chain, & &1["type"])
      assert "goal" in types
      assert "action" in types
    end
  end

  # ── Sync and Backup Workflow ───────────────────────────

  describe "sync and backup with real git history" do
    test "exports graph data and git history to files", %{repo: repo, initial_sha: sha} do
      ctx = context(repo)

      # Create nodes with real commit references
      capture_log(fn ->
        assert {:ok, _} =
                 exec(Commands.Add, ["goal", "Build API", "--commit", sha], ctx)

        assert {:ok, _} =
                 exec(Commands.Add, ["action", "Add endpoints", "--commit", sha], ctx)
      end)

      # Sync to tmp dir
      output_dir = Path.join(repo, "deploy")

      capture_log(fn ->
        config = Commands.Sync.parse(["-o", output_dir]) |> Map.merge(ctx)
        assert :ok = Commands.Sync.execute(config)
      end)

      assert File.exists?(Path.join(output_dir, "graph-data.json"))
      assert File.exists?(Path.join(output_dir, "git-history.json"))

      graph_data =
        output_dir
        |> Path.join("graph-data.json")
        |> File.read!()
        |> Jason.decode!()

      assert length(graph_data["nodes"]) == 2
      assert graph_data["stats"]["nodes"] == 2

      git_history =
        output_dir
        |> Path.join("git-history.json")
        |> File.read!()
        |> Jason.decode!()

      # Both nodes have commit metadata
      assert length(git_history) == 2

      # Backup
      backup_path = Path.join(repo, "backup.json")

      capture_log(fn ->
        config = Commands.Backup.parse(["-o", backup_path]) |> Map.merge(ctx)
        assert :ok = Commands.Backup.execute(config)
      end)

      assert File.exists?(backup_path)
      backup_data = backup_path |> File.read!() |> Jason.decode!()
      assert backup_data["stats"]["nodes"] == 2
      assert length(backup_data["nodes"]) == 2
    end
  end

  # ── Tag Management ─────────────────────────────────────

  describe "tag management across multiple nodes" do
    test "add, list, remove tags with real graph", %{repo: repo} do
      ctx = context(repo)

      # Create nodes
      capture_log(fn ->
        assert {:ok, _} = exec(Commands.Add, ["goal", "Auth feature", "-c", "90"], ctx)
        assert {:ok, _} = exec(Commands.Add, ["action", "Write auth code"], ctx)
      end)

      [goal] = Graph.list_nodes(node_type: :goal)
      [action] = Graph.list_nodes(node_type: :action)

      # Tag nodes
      capture_log(fn ->
        assert :ok = exec(Commands.Tag, ["add", "#{goal.id}", "auth"], ctx)
        assert :ok = exec(Commands.Tag, ["add", "#{goal.id}", "priority-high"], ctx)
        assert :ok = exec(Commands.Tag, ["add", "#{action.id}", "auth"], ctx)
      end)

      # Verify tags on goal
      goal = Graph.get_node(goal.id)
      assert "auth" in goal.metadata["tags"]
      assert "priority-high" in goal.metadata["tags"]

      # List all tags
      all_tags_output =
        capture_io(fn ->
          assert :ok = exec(Commands.Tag, ["list", "--json"], ctx)
        end)

      tag_map = Jason.decode!(all_tags_output)
      assert Map.has_key?(tag_map, "auth")
      assert length(tag_map["auth"]) == 2

      # Remove a tag
      capture_log(fn ->
        assert :ok = exec(Commands.Tag, ["remove", "#{goal.id}", "priority-high"], ctx)
      end)

      goal = Graph.get_node(goal.id)
      refute "priority-high" in goal.metadata["tags"]
      assert "auth" in goal.metadata["tags"]
    end
  end

  # ── Archaeology with Real Git History ──────────────────

  describe "archaeology mines real git history" do
    test "parses commits and creates nodes from real repo", %{repo: repo} do
      # Make several real commits with conventional prefixes
      write_code!(repo, "lib/user.ex", """
      defmodule User do
        defstruct [:id, :email, :name]
      end
      """)

      commit!(repo, ["lib/user.ex"], "feat: add user model")

      write_code!(repo, "lib/user.ex", """
      defmodule User do
        defstruct [:id, :email, :name]
        def valid_email?(%{email: e}), do: String.contains?(e, "@")
      end
      """)

      commit!(repo, ["lib/user.ex"], "fix: validate email format")

      write_code!(repo, "lib/auth.ex", """
      defmodule Auth do
        def authenticate(email, _password), do: {:ok, email}
      end
      """)

      commit!(repo, ["lib/auth.ex"], "refactor: extract auth module")

      ctx = context(repo)

      # Archaeology uses GitPort which reads from the project repo (not tmp_dir).
      # We test by running git log directly against the tmp_dir and feeding
      # the parsed output through the command's dry-run mode against the
      # project's GitPort. For real repo testing, we verify that archaeology
      # can parse and create nodes from whatever git log returns.

      # Dry run — uses the project's actual git log via GitPort
      dry_output =
        capture_io(fn ->
          capture_log(fn ->
            config =
              Commands.Archaeology.parse(["--dry-run", "-n", "5"])
              |> Map.merge(ctx)

            assert :ok = Commands.Archaeology.execute(config)
          end)
        end)

      assert dry_output =~ "Dry Run"
      assert dry_output =~ "Would create"

      # Create nodes from git history (project's real commits)
      capture_io(fn ->
        capture_log(fn ->
          config =
            Commands.Archaeology.parse(["-n", "3"])
            |> Map.merge(ctx)

          assert :ok = Commands.Archaeology.execute(config)
        end)
      end)

      # Verify nodes were created with commit metadata
      all_nodes = Graph.list_nodes()
      nodes_with_commits = Enum.filter(all_nodes, fn n -> n.metadata["commit"] != nil end)
      # CI uses shallow clone (depth=1), so may only have 1 commit
      assert nodes_with_commits != []

      # Verify each has a real commit SHA
      Enum.each(nodes_with_commits, fn node ->
        assert is_binary(node.metadata["commit"])
        assert String.length(node.metadata["commit"]) >= 7
      end)

      # Also verify we can parse the tmp_dir's git log directly
      {log_output, 0} =
        System.cmd("git", ["-C", repo, "log", "--oneline", "--no-merges", "-n", "5"])

      lines = String.split(log_output, "\n", trim: true)
      # initial + 3 conventional commits
      assert length(lines) == 4
      assert Enum.any?(lines, &String.contains?(&1, "feat: add user model"))
      assert Enum.any?(lines, &String.contains?(&1, "fix: validate email format"))
      assert Enum.any?(lines, &String.contains?(&1, "refactor: extract auth module"))
    end
  end

  # ── Multi-Branch Workflow ──────────────────────────────

  describe "multi-branch workflow" do
    test "nodes track branch context from real git branches", %{repo: repo} do
      ctx_main = context(repo)

      # Create goal on main
      capture_log(fn ->
        assert {:ok, _} = exec(Commands.Add, ["goal", "Main branch goal"], ctx_main)
      end)

      # Create a real feature branch
      git!(repo, ["checkout", "-b", "feature-auth"])
      ctx_feature = context(repo)
      assert ctx_feature.git_branch == "feature-auth"

      # Write code on feature branch
      write_code!(repo, "lib/feature.ex", """
      defmodule Feature do
        def new_feature, do: :ok
      end
      """)

      feature_sha = commit!(repo, ["lib/feature.ex"], "feat: add feature module")
      ctx_feature = context(repo)

      # Create action on feature branch with real commit
      capture_log(fn ->
        assert {:ok, _} =
                 exec(
                   Commands.Add,
                   ["action", "Feature branch action", "--commit", feature_sha],
                   ctx_feature
                 )
      end)

      # Go back to main
      git!(repo, ["checkout", "main"])

      # Add another action on main
      write_code!(repo, "lib/main_work.ex", """
      defmodule MainWork do
        def work, do: :done
      end
      """)

      main_sha = commit!(repo, ["lib/main_work.ex"], "feat: main branch work")
      ctx_main = context(repo)

      capture_log(fn ->
        assert {:ok, _} =
                 exec(
                   Commands.Add,
                   ["action", "Main branch action", "--commit", main_sha],
                   ctx_main
                 )
      end)

      # Filter by branch
      main_nodes = Graph.list_nodes(branch: "main")
      feature_nodes = Graph.list_nodes(branch: "feature-auth")

      assert main_nodes != []
      assert feature_nodes != []

      # Verify branch metadata is correct
      main_titles = Enum.map(main_nodes, & &1.title)
      feature_titles = Enum.map(feature_nodes, & &1.title)

      assert Enum.any?(main_titles, &String.contains?(&1, "Main"))
      assert Enum.any?(feature_titles, &String.contains?(&1, "Feature"))
    end
  end

  # ── Writeup Report Generation ──────────────────────────

  describe "writeup from a real decision subgraph" do
    test "generates markdown report with all sections", %{repo: repo} do
      ctx = context(repo)

      # Build a complete subgraph
      capture_log(fn ->
        assert {:ok, %{active_goal: goal_id}} =
                 exec(Commands.Add, ["goal", "Writeup Test Goal", "-c", "85"], ctx)

        ctx_with_goal = %{ctx | active_goal: goal_id}
        assert {:ok, _} = exec(Commands.Add, ["action", "Wrote some code"], ctx_with_goal)
        assert {:ok, _} = exec(Commands.Add, ["outcome", "It worked great"], ctx_with_goal)
      end)

      [goal] = Graph.list_nodes(node_type: :goal)
      [action] = Graph.list_nodes(node_type: :action)
      [outcome] = Graph.list_nodes(node_type: :outcome)

      capture_log(fn ->
        assert :ok = exec(Commands.Link, ["#{goal.id}", "#{action.id}", "-r", "impl"], ctx)
        assert :ok = exec(Commands.Link, ["#{action.id}", "#{outcome.id}", "-r", "result"], ctx)
      end)

      # Generate report for the goal's subgraph
      output =
        capture_io(fn ->
          assert :ok = exec(Commands.Writeup, ["--node", "#{goal.id}"], ctx)
        end)

      assert output =~ "Decision Graph Report"
      assert output =~ "Goals"
      assert output =~ "Writeup Test Goal"
      assert output =~ "Actions Taken"
      assert output =~ "Wrote some code"
      assert output =~ "Outcomes"
      assert output =~ "It worked great"

      # Write to file
      report_path = Path.join(repo, "WRITEUP.md")

      assert :ok =
               exec(
                 Commands.Writeup,
                 ["--node", "#{goal.id}", "-o", report_path],
                 ctx
               )

      assert File.exists?(report_path)
      content = File.read!(report_path)
      assert content =~ "# Decision Graph Report"
    end
  end

  # ── Init and Version Management ────────────────────────

  describe "init, check-update, and update lifecycle" do
    test "full init → update → check-update cycle", %{repo: repo} do
      original_dir = File.cwd!()
      File.cd!(repo)

      ctx = context(repo)

      # Init creates directory structure
      capture_log(fn ->
        assert :ok = exec(Commands.Init, [], ctx)
      end)

      assert File.dir?(".deciduous")
      assert File.dir?(".deciduous/documents")
      assert File.dir?(".deciduous/backups")
      assert File.exists?(".deciduous/config.toml")
      assert File.exists?(".deciduous/.version")

      config_content = File.read!(".deciduous/config.toml")
      assert config_content =~ "main_branches"
      assert config_content =~ "auto_detect"

      # Check-update should report up to date
      check_output =
        capture_io(fn ->
          capture_log(fn ->
            assert :ok = exec(Commands.CheckUpdate, ["--json"], ctx)
          end)
        end)

      check_data = Jason.decode!(check_output)
      assert check_data["update_available"] == false

      # Idempotent — init again without --force
      capture_log(fn ->
        assert :ok = exec(Commands.Init, [], ctx)
      end)

      # Init with --force overwrites
      capture_log(fn ->
        assert :ok = exec(Commands.Init, ["--force"], ctx)
      end)

      File.cd!(original_dir)
    end
  end

  # ── Doc Attachment Workflow ────────────────────────────

  describe "doc attachment with real files" do
    test "attach, list, show, detach lifecycle", %{repo: repo} do
      original_dir = File.cwd!()
      File.cd!(repo)
      File.mkdir_p!(".deciduous/documents")

      ctx = context(repo)

      # Create a node to attach docs to
      capture_log(fn ->
        assert {:ok, _} = exec(Commands.Add, ["goal", "Doc Test Goal"], ctx)
      end)

      [goal] = Graph.list_nodes(node_type: :goal)

      # Create a real document file
      doc_path = Path.join(repo, "architecture.md")

      File.write!(doc_path, """
      # Architecture

      This document describes the system architecture.

      ## Components
      - Auth module
      - API layer
      - Database
      """)

      # Attach the document
      capture_log(fn ->
        assert :ok =
                 exec(
                   Commands.Doc,
                   ["attach", "#{goal.id}", doc_path, "-d", "Architecture diagram"],
                   ctx
                 )
      end)

      # List documents for the node
      list_output =
        capture_io(fn ->
          assert :ok = exec(Commands.Doc, ["list", "#{goal.id}"], ctx)
        end)

      assert list_output =~ "architecture.md"

      # List all documents
      all_output =
        capture_io(fn ->
          assert :ok = exec(Commands.Doc, ["list"], ctx)
        end)

      assert all_output =~ "architecture.md"

      # Verify the file was copied to storage
      docs = Graph.list_documents(goal.id)
      assert length(docs) == 1
      [doc] = docs
      assert doc.original_filename == "architecture.md"
      assert doc.description == "Architecture diagram"
      assert doc.file_size > 0

      # Show document detail
      show_output =
        capture_io(fn ->
          assert :ok = exec(Commands.Doc, ["show", "#{doc.id}"], ctx)
        end)

      assert show_output =~ "architecture.md"
      assert show_output =~ "Architecture diagram"

      # Detach the document
      capture_log(fn ->
        assert :ok = exec(Commands.Doc, ["detach", "#{doc.id}"], ctx)
      end)

      # Should no longer appear in list
      empty_output =
        capture_io(fn ->
          assert :ok = exec(Commands.Doc, ["list", "#{goal.id}"], ctx)
        end)

      assert empty_output =~ "No documents found"

      File.cd!(original_dir)
    end
  end

  # ── Themes ─────────────────────────────────────────────

  describe "themes with real config files" do
    test "list, set, and current theme", %{repo: repo} do
      original_dir = File.cwd!()
      File.cd!(repo)
      ctx = context(repo)

      # List themes
      list_output =
        capture_io(fn ->
          assert :ok = exec(Commands.Themes, ["list"], ctx)
        end)

      assert list_output =~ "default"
      assert list_output =~ "dark"
      assert list_output =~ "light"

      # Set theme
      capture_log(fn ->
        assert :ok = exec(Commands.Themes, ["set", "dark"], ctx)
      end)

      # Verify theme file written
      assert File.exists?(".deciduous/theme")
      assert File.read!(".deciduous/theme") == "dark"

      # Current theme
      current_output =
        capture_io(fn ->
          assert :ok = exec(Commands.Themes, ["current"], ctx)
        end)

      assert current_output =~ "dark"

      # Invalid theme
      capture_log(fn ->
        assert {:error, "unknown theme"} = exec(Commands.Themes, ["set", "neon"], ctx)
      end)

      File.cd!(original_dir)
    end
  end

  # ── Hooks ──────────────────────────────────────────────

  describe "hooks with real directory" do
    test "list and status commands work", %{repo: repo} do
      original_dir = File.cwd!()
      File.cd!(repo)
      ctx = context(repo)

      # Create hooks directory with a real hook script
      hooks_dir = Path.join(repo, ".claude/hooks")
      File.mkdir_p!(hooks_dir)

      File.write!(Path.join(hooks_dir, "test-hook.sh"), """
      #!/bin/bash
      echo "test hook"
      """)

      # List hooks
      list_output =
        capture_io(fn ->
          assert :ok = exec(Commands.Hooks, ["list"], ctx)
        end)

      assert list_output =~ "test-hook"

      # Status
      status_output =
        capture_io(fn ->
          assert :ok = exec(Commands.Hooks, ["status"], ctx)
        end)

      assert status_output =~ "test-hook"
      assert status_output =~ "inactive"

      File.cd!(original_dir)
    end
  end

  # ── Stats Across Full Graph ────────────────────────────

  describe "stats on a populated graph" do
    test "accurate counts after building a decision graph", %{repo: repo} do
      ctx = context(repo)

      # Build a real graph
      capture_log(fn ->
        assert {:ok, _} = exec(Commands.Add, ["goal", "Stats Goal"], ctx)
        assert {:ok, _} = exec(Commands.Add, ["option", "Option A"], ctx)
        assert {:ok, _} = exec(Commands.Add, ["option", "Option B"], ctx)
        assert {:ok, _} = exec(Commands.Add, ["decision", "Pick A"], ctx)
        assert {:ok, _} = exec(Commands.Add, ["action", "Build A"], ctx)
        assert {:ok, _} = exec(Commands.Add, ["outcome", "A works"], ctx)
        assert {:ok, _} = exec(Commands.Add, ["observation", "Noted something"], ctx)
      end)

      stats_output =
        capture_io(fn ->
          assert :ok = exec(Commands.Stats, ["--json"], ctx)
        end)

      data = Jason.decode!(stats_output)
      assert data["totals"]["nodes"] == 7
      assert data["by_type"]["goal"] == 1
      assert data["by_type"]["option"] == 2
      assert data["by_type"]["decision"] == 1
      assert data["by_type"]["action"] == 1
      assert data["by_type"]["outcome"] == 1
      assert data["by_type"]["observation"] == 1
    end
  end

  # ── Supersede with Full Context ────────────────────────

  describe "supersede in context of real development" do
    test "supersede a goal and verify graph integrity", %{repo: repo} do
      ctx = context(repo)

      capture_log(fn ->
        assert {:ok, _} = exec(Commands.Add, ["goal", "Old approach v1"], ctx)
        assert {:ok, _} = exec(Commands.Add, ["goal", "New approach v2"], ctx)
      end)

      goals = Graph.list_nodes(node_type: :goal)
      old = Enum.find(goals, &(&1.title == "Old approach v1"))
      new = Enum.find(goals, &(&1.title == "New approach v2"))

      capture_log(fn ->
        assert :ok =
                 exec(
                   Commands.Supersede,
                   ["#{old.id}", "#{new.id}", "-r", "better architecture"],
                   ctx
                 )
      end)

      assert Graph.get_node(old.id).status == :superseded
      edges = Graph.edges_from(old.id)
      assert length(edges) == 1
      assert hd(edges).to_node_id == new.id
      assert hd(edges).rationale == "better architecture"
    end
  end

  # ── Serve ──────────────────────────────────────────────

  describe "serve reports endpoint status" do
    test "reports without crashing", %{repo: repo} do
      ctx = context(repo)

      capture_log(fn ->
        assert :ok = exec(Commands.Serve, [], ctx)
      end)
    end
  end
end
