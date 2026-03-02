defmodule Decidulixir.Update do
  @moduledoc """
  Update tooling files to the latest version.

  Auto-detects which backends are installed and overwrites their files.
  Separate from Init — this is the regeneration path.
  """

  alias Decidulixir.CLI.Formatter
  alias Decidulixir.Init.{FileWriter, Validator, Version}
  alias Decidulixir.Init.Templates.Shared

  @backends [
    {:claude, Decidulixir.Init.Templates.Claude},
    {:opencode, Decidulixir.Init.Templates.OpenCode},
    {:windsurf, Decidulixir.Init.Templates.Windsurf}
  ]

  @doc """
  Update all installed backend tooling files.

  Auto-detects which backends are installed by checking for their directories.
  Overwrites all template files with the latest versions.
  """
  @spec update(keyword()) :: :ok | {:error, String.t()}
  def update(opts \\ []) do
    project_root = Keyword.get_lazy(opts, :project_root, fn -> File.cwd!() end)

    unless Validator.initialized?(project_root) do
      Formatter.warn(".deciduous/ not found — run 'mix decidulixir init' first")
    end

    # Auto-detect installed backends
    installed =
      @backends
      |> Enum.filter(fn {_key, module} -> module.detect?(project_root) end)

    if installed == [] do
      Formatter.error("no assistant integration found — run 'mix decidulixir init' first")
      {:error, "no backends installed"}
    else
      names = installed |> Enum.map(fn {_key, mod} -> mod.name() end) |> Enum.join(" + ")
      Formatter.info("\nUpdating Decidulixir tooling for #{names}...")
      Formatter.info("  Directory: #{project_root}\n")

      # Overwrite backend files
      Enum.each(installed, fn {_key, module} ->
        files = module.files(project_root)
        FileWriter.write_batch(files, project_root, overwrite: true)
      end)

      # Overwrite shared files
      shared_files = Shared.files(project_root)
      FileWriter.write_batch(shared_files, project_root, overwrite: true)

      # Run post_init (e.g., update CLAUDE.md section)
      Enum.each(installed, fn {_key, module} ->
        module.post_init(project_root)
      end)

      # Update version
      Version.write(project_root)

      Formatter.success("\nTooling updated for #{names}!")
      :ok
    end
  end
end
