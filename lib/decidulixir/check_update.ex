defmodule Decidulixir.CheckUpdate do
  @moduledoc """
  Version comparison for update detection.
  """

  alias Decidulixir.CLI.Formatter
  alias Decidulixir.Init.Version

  @doc """
  Check if tooling files need updating.

  Compares `.deciduous/.version` against the current app version.
  """
  @spec check(keyword()) :: :up_to_date | :update_available | :not_initialized
  def check(opts \\ []) do
    project_root = Keyword.get_lazy(opts, :project_root, fn -> File.cwd!() end)

    case Version.installed(project_root) do
      {:ok, installed} ->
        current = Version.current()

        if installed == current do
          Formatter.success("Decidulixir tooling is up to date (v#{current})")
          :up_to_date
        else
          Formatter.warn("Update available: v#{installed} -> v#{current}")
          IO.puts("  Run 'mix decidulixir update' to update tooling files.")
          :update_available
        end

      :not_found ->
        Formatter.warn("Decidulixir not initialized — run 'mix decidulixir init' first")
        :not_initialized
    end
  end
end
