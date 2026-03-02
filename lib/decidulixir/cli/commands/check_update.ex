defmodule Decidulixir.CLI.Commands.CheckUpdate do
  @moduledoc "Check if deciduous needs updating."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "check-update"

  @impl true
  def description, do: "Check for updates"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv, strict: [json: :boolean])

    %{json: opts[:json] || false}
  end

  @impl true
  def execute(%{json: json}) do
    current = Mix.Project.config()[:version] || "0.0.0"

    case File.read(".deciduous/.version") do
      {:ok, installed} ->
        installed = String.trim(installed)

        result = %{
          installed: installed,
          current: current,
          update_available: installed != current
        }

        if json do
          IO.puts(Jason.encode!(result, pretty: true))
        else
          print_result(result)
        end

        :ok

      {:error, _} ->
        if json do
          IO.puts(Jason.encode!(%{error: "not initialized"}, pretty: true))
        else
          Logger.info("Not initialized. Run 'init' first.")
        end

        :ok
    end
  end

  defp print_result(%{update_available: true} = r) do
    IO.puts("Update available: #{r.installed} -> #{r.current}")
    IO.puts("Run 'update' to update.")
  end

  defp print_result(%{update_available: false} = r) do
    IO.puts("Up to date (#{r.current})")
  end
end
