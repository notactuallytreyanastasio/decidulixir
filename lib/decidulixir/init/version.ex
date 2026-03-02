defmodule Decidulixir.Init.Version do
  @moduledoc """
  Version tracking for decidulixir tooling files.

  Writes and reads `.deciduous/.version` for update detection.
  """

  @doc "Returns the current decidulixir version from mix.exs."
  @spec current() :: String.t()
  def current do
    Application.spec(:decidulixir, :vsn) |> to_string()
  end

  @doc "Read the installed version from .deciduous/.version."
  @spec installed(Path.t()) :: {:ok, String.t()} | :not_found
  def installed(project_root) do
    path = version_path(project_root)

    case File.read(path) do
      {:ok, content} -> {:ok, String.trim(content)}
      {:error, _} -> :not_found
    end
  end

  @doc "Write the current version to .deciduous/.version."
  @spec write(Path.t()) :: :ok
  def write(project_root) do
    path = version_path(project_root)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, current())
    :ok
  end

  @doc "Check if an update is available."
  @spec update_available?(Path.t()) :: boolean()
  def update_available?(project_root) do
    case installed(project_root) do
      {:ok, installed_version} -> installed_version != current()
      :not_found -> false
    end
  end

  defp version_path(project_root) do
    Path.join([project_root, ".deciduous", ".version"])
  end
end
