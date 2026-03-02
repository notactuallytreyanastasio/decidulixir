defmodule Decidulixir.InitTest do
  use ExUnit.Case, async: true

  alias Decidulixir.{CheckUpdate, Init, Update}
  alias Decidulixir.Init.{FileWriter, Validator, Version}
  alias Decidulixir.Init.Templates.{Claude, OpenCode, Shared, Windsurf}

  @moduletag :tmp_dir

  describe "Validator" do
    test "requires at least one backend" do
      assert {:error, _} = Validator.validate(backends: [])
    end

    test "accepts valid backends" do
      assert :ok = Validator.validate(backends: [:claude])
      assert :ok = Validator.validate(backends: [:opencode])
      assert :ok = Validator.validate(backends: [:claude, :windsurf])
    end

    test "detects git repo", %{tmp_dir: tmp} do
      refute Validator.git_repo?(tmp)
      File.mkdir_p!(Path.join(tmp, ".git"))
      assert Validator.git_repo?(tmp)
    end

    test "detects initialization", %{tmp_dir: tmp} do
      refute Validator.initialized?(tmp)
      File.mkdir_p!(Path.join(tmp, ".deciduous"))
      assert Validator.initialized?(tmp)
    end
  end

  describe "Version" do
    test "writes and reads version", %{tmp_dir: tmp} do
      assert :not_found = Version.installed(tmp)
      Version.write(tmp)
      assert {:ok, version} = Version.installed(tmp)
      assert version == Version.current()
    end

    test "detects update available", %{tmp_dir: tmp} do
      refute Version.update_available?(tmp)
      # Write a different version
      path = Path.join([tmp, ".deciduous", ".version"])
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "0.0.1")
      assert Version.update_available?(tmp)
    end
  end

  describe "FileWriter" do
    test "write_if_missing creates new file", %{tmp_dir: tmp} do
      path = Path.join(tmp, "new_file.txt")
      assert :ok = FileWriter.write_if_missing(path, "hello")
      assert File.read!(path) == "hello"
    end

    test "write_if_missing skips existing file", %{tmp_dir: tmp} do
      path = Path.join(tmp, "existing.txt")
      File.write!(path, "original")
      assert :skipped = FileWriter.write_if_missing(path, "new content")
      assert File.read!(path) == "original"
    end

    test "write_overwrite replaces existing file", %{tmp_dir: tmp} do
      path = Path.join(tmp, "overwrite.txt")
      File.write!(path, "original")
      FileWriter.write_overwrite(path, "new content")
      assert File.read!(path) == "new content"
    end

    test "write_executable_if_missing sets chmod", %{tmp_dir: tmp} do
      path = Path.join(tmp, "hook.sh")
      assert :ok = FileWriter.write_executable_if_missing(path, "#!/bin/bash")
      assert File.read!(path) == "#!/bin/bash"
      {:ok, stat} = File.stat(path)
      # Check that the file is executable (owner execute bit)
      assert Bitwise.band(stat.mode, 0o100) == 0o100
    end

    test "add_to_gitignore appends entry", %{tmp_dir: tmp} do
      gitignore = Path.join(tmp, ".gitignore")
      File.write!(gitignore, "node_modules/\n")
      FileWriter.add_to_gitignore(tmp, ".deciduous/")
      content = File.read!(gitignore)
      assert String.contains?(content, ".deciduous/")
      assert String.contains?(content, "node_modules/")
    end

    test "add_to_gitignore skips duplicate", %{tmp_dir: tmp} do
      gitignore = Path.join(tmp, ".gitignore")
      File.write!(gitignore, ".deciduous/\n")
      FileWriter.add_to_gitignore(tmp, ".deciduous/")
      content = File.read!(gitignore)
      # Should appear only once
      assert length(String.split(content, ".deciduous/")) == 2
    end

    test "update_markdown_section appends when no markers", %{tmp_dir: tmp} do
      md_path = Path.join(tmp, "CLAUDE.md")
      File.write!(md_path, "# Project\n\nExisting content.\n")
      FileWriter.update_markdown_section(md_path, "## New Section\nContent here.")
      content = File.read!(md_path)
      assert String.contains?(content, "<!-- deciduous:start -->")
      assert String.contains?(content, "## New Section")
      assert String.contains?(content, "<!-- deciduous:end -->")
      assert String.contains?(content, "Existing content.")
    end

    test "update_markdown_section replaces between markers", %{tmp_dir: tmp} do
      md_path = Path.join(tmp, "CLAUDE.md")

      File.write!(md_path, """
      # Project
      <!-- deciduous:start -->
      ## Old Content
      <!-- deciduous:end -->
      Footer
      """)

      FileWriter.update_markdown_section(md_path, "## Updated Content")
      content = File.read!(md_path)
      assert String.contains?(content, "## Updated Content")
      refute String.contains?(content, "## Old Content")
      assert String.contains?(content, "Footer")
    end

    test "write_batch writes multiple files", %{tmp_dir: tmp} do
      files = [
        {"a/b.txt", "content b"},
        {"c.txt", "content c"}
      ]

      count = FileWriter.write_batch(files, tmp)
      assert count == 2
      assert File.read!(Path.join(tmp, "a/b.txt")) == "content b"
      assert File.read!(Path.join(tmp, "c.txt")) == "content c"
    end
  end

  describe "Templates" do
    test "Claude backend returns files" do
      [_ | _] = files = Claude.files("/tmp/test")
      paths = Enum.map(files, &elem(&1, 0))
      assert ".claude/commands/decision.md" in paths
      assert ".claude/commands/recover.md" in paths
      assert ".claude/commands/work.md" in paths
      assert ".claude/hooks/require-action-node.sh" in paths
      assert ".claude/skills/pulse.md" in paths
      assert ".claude/agents.toml" in paths
    end

    test "OpenCode backend returns files" do
      files = OpenCode.files("/tmp/test")
      paths = Enum.map(files, &elem(&1, 0))
      assert ".opencode/commands/decision.md" in paths
      assert ".opencode/opencode.json" in paths
    end

    test "Windsurf backend returns files" do
      files = Windsurf.files("/tmp/test")
      paths = Enum.map(files, &elem(&1, 0))
      assert ".windsurf/hooks.json" in paths
      assert ".windsurf/rules/deciduous.md" in paths
    end

    test "Shared returns infrastructure files" do
      files = Shared.files("/tmp/test")
      paths = Enum.map(files, &elem(&1, 0))
      assert ".deciduous/config.toml" in paths
      assert "docs/graph-data.json" in paths
    end

    test "Claude detect? checks for .claude dir" do
      refute Claude.detect?("/nonexistent")
    end

    test "all templates have non-empty content" do
      for {_path, content} <- Claude.files("/tmp") do
        assert String.length(content) > 0
      end
    end
  end

  describe "Init.init_project" do
    test "creates all Claude files", %{tmp_dir: tmp} do
      # Create .git so workflows are generated too
      File.mkdir_p!(Path.join(tmp, ".git"))

      assert :ok = Init.init_project(backends: [:claude], project_root: tmp)

      # Check infrastructure
      assert File.dir?(Path.join(tmp, ".deciduous"))
      assert File.dir?(Path.join(tmp, ".deciduous/documents"))
      assert File.exists?(Path.join(tmp, ".deciduous/config.toml"))
      assert File.exists?(Path.join(tmp, ".deciduous/.version"))

      # Check Claude files
      assert File.exists?(Path.join(tmp, ".claude/commands/decision.md"))
      assert File.exists?(Path.join(tmp, ".claude/commands/recover.md"))
      assert File.exists?(Path.join(tmp, ".claude/commands/work.md"))
      assert File.exists?(Path.join(tmp, ".claude/hooks/require-action-node.sh"))
      assert File.exists?(Path.join(tmp, ".claude/skills/pulse.md"))
      assert File.exists?(Path.join(tmp, ".claude/agents.toml"))
      assert File.exists?(Path.join(tmp, ".claude/settings.json"))

      # Check CLAUDE.md was created
      assert File.exists?(Path.join(tmp, "CLAUDE.md"))
      claude_md = File.read!(Path.join(tmp, "CLAUDE.md"))
      assert String.contains?(claude_md, "deciduous:start")
      assert String.contains?(claude_md, "mix decidulixir")

      # Check docs
      assert File.exists?(Path.join(tmp, "docs/graph-data.json"))
      assert File.exists?(Path.join(tmp, "docs/.nojekyll"))

      # Check workflows
      assert File.exists?(Path.join(tmp, ".github/workflows/cleanup-decision-graphs.yml"))
      assert File.exists?(Path.join(tmp, ".github/workflows/deploy-pages.yml"))

      # Check .gitignore
      gitignore = File.read!(Path.join(tmp, ".gitignore"))
      assert String.contains?(gitignore, ".deciduous/")

      # Check version
      {:ok, version} = Version.installed(tmp)
      assert version == Version.current()
    end

    test "is idempotent", %{tmp_dir: tmp} do
      assert :ok = Init.init_project(backends: [:claude], project_root: tmp)
      assert :ok = Init.init_project(backends: [:claude], project_root: tmp)

      # Files should still exist
      assert File.exists?(Path.join(tmp, ".claude/commands/decision.md"))
    end

    test "creates OpenCode files", %{tmp_dir: tmp} do
      assert :ok = Init.init_project(backends: [:opencode], project_root: tmp)
      assert File.exists?(Path.join(tmp, ".opencode/commands/decision.md"))
      assert File.exists?(Path.join(tmp, ".opencode/opencode.json"))
    end

    test "creates Windsurf files", %{tmp_dir: tmp} do
      assert :ok = Init.init_project(backends: [:windsurf], project_root: tmp)
      assert File.exists?(Path.join(tmp, ".windsurf/hooks.json"))
      assert File.exists?(Path.join(tmp, ".windsurf/rules/deciduous.md"))
    end

    test "creates multiple backends", %{tmp_dir: tmp} do
      assert :ok = Init.init_project(backends: [:claude, :opencode], project_root: tmp)
      assert File.exists?(Path.join(tmp, ".claude/commands/decision.md"))
      assert File.exists?(Path.join(tmp, ".opencode/commands/decision.md"))
    end
  end

  describe "Update" do
    test "updates installed backend files", %{tmp_dir: tmp} do
      # First init
      Init.init_project(backends: [:claude], project_root: tmp)

      # Modify a file
      decision_path = Path.join(tmp, ".claude/commands/decision.md")
      File.write!(decision_path, "modified content")

      # Update should overwrite
      assert :ok = Update.update(project_root: tmp)
      content = File.read!(decision_path)
      refute content == "modified content"
      assert String.contains?(content, "decision")
    end

    test "fails when no backends installed", %{tmp_dir: tmp} do
      assert {:error, _} = Update.update(project_root: tmp)
    end
  end

  describe "CheckUpdate" do
    test "reports up to date", %{tmp_dir: tmp} do
      Init.init_project(backends: [:claude], project_root: tmp)
      assert :up_to_date = CheckUpdate.check(project_root: tmp)
    end

    test "reports not initialized", %{tmp_dir: tmp} do
      assert :not_initialized = CheckUpdate.check(project_root: tmp)
    end

    test "reports update available", %{tmp_dir: tmp} do
      Init.init_project(backends: [:claude], project_root: tmp)
      # Write old version
      version_path = Path.join([tmp, ".deciduous", ".version"])
      File.write!(version_path, "0.0.1")
      assert :update_available = CheckUpdate.check(project_root: tmp)
    end
  end
end
