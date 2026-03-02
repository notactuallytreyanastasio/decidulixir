defmodule Decidulixir.CLI.Commands.Init do
  @moduledoc "Initialize deciduous directory structure in a project."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "init"

  @impl true
  def description, do: "Initialize deciduous: init [--force]"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [force: :boolean],
        aliases: [f: :force]
      )

    %{force: opts[:force] || false}
  end

  @impl true
  def execute(%{force: force}) do
    if not force and File.dir?(".deciduous") do
      Logger.info("Already initialized. Use --force to reinitialize.")
      :ok
    else
      create_directories()
      write_config(force)
      write_version()
      Logger.info("Initialized deciduous in current directory")
      :ok
    end
  end

  defp create_directories do
    Enum.each(
      [".deciduous", ".deciduous/documents", ".deciduous/backups", "docs"],
      &File.mkdir_p!/1
    )
  end

  defp write_config(force) do
    path = ".deciduous/config.toml"

    if force or not File.exists?(path) do
      File.write!(path, default_config())
    end
  end

  defp write_version do
    version = Mix.Project.config()[:version] || "0.0.0"
    File.write!(".deciduous/.version", version)
  end

  defp default_config do
    """
    # Deciduous configuration

    [branch]
    main_branches = ["main", "master"]
    auto_detect = true

    [sync]
    output_dir = "docs"

    [documents]
    storage_backend = "local"
    storage_path = ".deciduous/documents"
    """
  end
end
