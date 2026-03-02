defmodule Decidulixir.Init do
  @moduledoc """
  Thin orchestrator for project initialization.

  Pipeline: validate -> setup infrastructure -> get backend files -> write -> post_init.
  """

  alias Decidulixir.CLI.Formatter
  alias Decidulixir.Init.{FileWriter, Validator, Version}
  alias Decidulixir.Init.Templates.Shared

  @backend_modules %{
    claude: Decidulixir.Init.Templates.Claude,
    opencode: Decidulixir.Init.Templates.OpenCode,
    windsurf: Decidulixir.Init.Templates.Windsurf
  }

  @doc """
  Initialize a new decidulixir project with AI assistant integration.

  ## Options

    * `:backends` - list of backend atoms: `[:claude]`, `[:opencode]`, `[:claude, :windsurf]`
    * `:project_root` - path to project root (defaults to cwd)

  """
  @spec init_project(keyword()) :: :ok | {:error, String.t()}
  def init_project(opts \\ []) do
    project_root = Keyword.get_lazy(opts, :project_root, fn -> File.cwd!() end)
    backends = Keyword.get(opts, :backends, [])

    # Also auto-detect Windsurf if .windsurf dir exists
    backends = maybe_add_windsurf(backends, project_root)

    with :ok <- Validator.validate(backends: backends) do
      backend_names = backends |> Enum.map(&backend_module/1) |> Enum.map(& &1.name())
      name_str = Enum.join(backend_names, " + ")

      Formatter.info("\nInitializing Decidulixir for #{name_str}...")
      Formatter.info("  Directory: #{project_root}\n")

      # 1. Create .deciduous infrastructure
      setup_infrastructure(project_root)

      # 2. Write shared files (config, docs)
      shared_files = Shared.files(project_root)
      FileWriter.write_batch(shared_files, project_root)

      # 3. Write workflow files if git repo
      if Validator.git_repo?(project_root) do
        workflow_files = Shared.workflow_files()
        FileWriter.write_batch(workflow_files, project_root)
      end

      # 4. Write backend-specific files
      Enum.each(backends, fn backend_key ->
        module = backend_module(backend_key)
        files = module.files(project_root)
        FileWriter.write_batch(files, project_root)
      end)

      # 5. Mark hook files as executable
      mark_hooks_executable(backends, project_root)

      # 6. Run post_init for each backend
      Enum.each(backends, fn backend_key ->
        module = backend_module(backend_key)
        module.post_init(project_root)
      end)

      # 7. Add .deciduous to .gitignore
      FileWriter.add_to_gitignore(project_root, ".deciduous/")

      # 8. Write version
      Version.write(project_root)

      Formatter.success("\nDecidulixir initialized for #{name_str}!")
      print_next_steps()
      :ok
    end
  end

  @doc "Returns the map of backend keys to modules."
  @spec backend_modules() :: %{atom() => module()}
  def backend_modules, do: @backend_modules

  defp backend_module(key), do: Map.fetch!(@backend_modules, key)

  defp setup_infrastructure(project_root) do
    deciduous_dir = Path.join(project_root, ".deciduous")
    documents_dir = Path.join(deciduous_dir, "documents")

    File.mkdir_p!(deciduous_dir)
    File.mkdir_p!(documents_dir)
  end

  defp maybe_add_windsurf(backends, project_root) do
    windsurf_dir = Path.join(project_root, ".windsurf")

    if :windsurf not in backends and File.dir?(windsurf_dir) do
      Formatter.info("Detected .windsurf directory — adding Windsurf integration")
      backends ++ [:windsurf]
    else
      backends
    end
  end

  defp mark_hooks_executable(backends, project_root) do
    hook_patterns = [
      {".claude/hooks/require-action-node.sh", :claude},
      {".claude/hooks/post-commit-reminder.sh", :claude},
      {".windsurf/hooks/require-action-node.sh", :windsurf},
      {".windsurf/hooks/post-commit-reminder.sh", :windsurf}
    ]

    Enum.each(hook_patterns, fn {rel_path, backend_key} ->
      if backend_key in backends do
        abs_path = Path.join(project_root, rel_path)

        if File.exists?(abs_path) do
          File.chmod!(abs_path, 0o755)
        end
      end
    end)
  end

  defp print_next_steps do
    IO.puts("\nNext steps:")
    IO.puts("  1. mix phx.server       — Start the graph viewer at localhost:4000/graph")
    IO.puts("  2. mix decidulixir nodes — List decision graph nodes")
    IO.puts("  3. mix decidulixir audit — Check for missing connections")
    IO.puts("")
  end
end
