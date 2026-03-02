defmodule Decidulixir.Init.FileWriter do
  @moduledoc """
  Single-responsibility file I/O for the init system.

  All disk writes flow through this module. Template modules produce
  `{path, content}` tuples; this module writes them.
  """

  alias Decidulixir.CLI.Formatter

  @doc "Write a file only if it doesn't already exist."
  @spec write_if_missing(Path.t(), String.t()) :: :ok | :skipped
  def write_if_missing(path, content) do
    if File.exists?(path) do
      Formatter.warn("#{relative(path)} (already exists, skipping)")
      :skipped
    else
      ensure_dir!(path)
      File.write!(path, content)
      Formatter.success("  Created #{relative(path)}")
      :ok
    end
  end

  @doc "Write a file, overwriting if it exists. Used by update."
  @spec write_overwrite(Path.t(), String.t()) :: :ok
  def write_overwrite(path, content) do
    ensure_dir!(path)
    File.write!(path, content)
    Formatter.success("  Updated #{relative(path)}")
    :ok
  end

  @doc "Write an executable file (chmod +x) only if it doesn't exist."
  @spec write_executable_if_missing(Path.t(), String.t()) :: :ok | :skipped
  def write_executable_if_missing(path, content) do
    case write_if_missing(path, content) do
      :ok ->
        File.chmod!(path, 0o755)
        :ok

      :skipped ->
        :skipped
    end
  end

  @doc "Add an entry to .gitignore if not already present."
  @spec add_to_gitignore(Path.t(), String.t()) :: :ok
  def add_to_gitignore(project_root, entry) do
    gitignore_path = Path.join(project_root, ".gitignore")

    if File.exists?(gitignore_path) do
      content = File.read!(gitignore_path)

      unless String.contains?(content, entry) do
        File.write!(gitignore_path, content <> "\n#{entry}\n")
        Formatter.success("  Added #{entry} to .gitignore")
      end
    else
      File.write!(gitignore_path, "#{entry}\n")
      Formatter.success("  Created .gitignore with #{entry}")
    end

    :ok
  end

  @doc """
  Update a markdown file's section between markers, or append if no markers found.

  Markers are HTML comments: `<!-- deciduous:start -->` and `<!-- deciduous:end -->`.
  """
  @spec update_markdown_section(Path.t(), String.t()) :: :ok
  def update_markdown_section(path, section_content) do
    start_marker = "<!-- deciduous:start -->"
    end_marker = "<!-- deciduous:end -->"
    full_section = "#{start_marker}\n#{section_content}\n#{end_marker}"

    if File.exists?(path) do
      content = File.read!(path)

      if String.contains?(content, start_marker) do
        # Replace existing section
        updated =
          Regex.replace(
            ~r/<!-- deciduous:start -->.*<!-- deciduous:end -->/s,
            content,
            full_section
          )

        File.write!(path, updated)
        Formatter.success("  Updated deciduous section in #{relative(path)}")
      else
        # Append
        File.write!(path, content <> "\n\n#{full_section}\n")
        Formatter.success("  Appended deciduous section to #{relative(path)}")
      end
    else
      File.write!(path, full_section <> "\n")
      Formatter.success("  Created #{relative(path)}")
    end

    :ok
  end

  @doc "Write a batch of `{path, content}` tuples. Returns count of files written."
  @spec write_batch([{String.t(), String.t()}], Path.t(), keyword()) :: non_neg_integer()
  def write_batch(files, project_root, opts \\ []) do
    overwrite? = Keyword.get(opts, :overwrite, false)

    files
    |> Enum.map(fn {rel_path, content} ->
      abs_path = Path.join(project_root, rel_path)

      if overwrite? do
        write_overwrite(abs_path, content)
        1
      else
        case write_if_missing(abs_path, content) do
          :ok -> 1
          :skipped -> 0
        end
      end
    end)
    |> Enum.sum()
  end

  defp ensure_dir!(path) do
    path |> Path.dirname() |> File.mkdir_p!()
  end

  defp relative(path) do
    case File.cwd() do
      {:ok, cwd} -> Path.relative_to(path, cwd)
      _ -> path
    end
  end
end
