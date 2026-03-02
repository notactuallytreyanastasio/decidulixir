defmodule Decidulixir.CLI.Commands.Hooks do
  @moduledoc "List and manage Claude Code hook scripts."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @hooks_dir ".claude/hooks"

  @impl true
  def name, do: "hooks"

  @impl true
  def description, do: "Manage hooks: hooks list|status"

  @impl true
  def parse(argv) do
    {opts, args, _invalid} =
      OptionParser.parse(argv,
        strict: [json: :boolean]
      )

    %{
      subcommand: List.first(args) || "list",
      json: opts[:json] || false
    }
  end

  @impl true
  def execute(%{subcommand: "list", json: json}) do
    hooks = list_hooks()

    if json do
      IO.puts(Jason.encode!(hooks, pretty: true))
    else
      print_hooks(hooks)
    end

    :ok
  end

  def execute(%{subcommand: "status", json: json}) do
    hooks = list_hooks()
    settings = read_settings()

    status =
      Enum.map(hooks, fn hook ->
        active = hook_active?(hook.name, settings)
        Map.put(hook, :active, active)
      end)

    if json do
      IO.puts(Jason.encode!(status, pretty: true))
    else
      print_status(status)
    end

    :ok
  end

  def execute(%{subcommand: sub}) do
    Logger.error("Unknown subcommand: #{sub}. Use list or status.")
    {:error, "unknown subcommand"}
  end

  defp list_hooks do
    case File.ls(@hooks_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".sh"))
        |> Enum.sort()
        |> Enum.map(fn file ->
          path = Path.join(@hooks_dir, file)
          %{name: Path.rootname(file), file: file, path: path}
        end)

      {:error, _} ->
        []
    end
  end

  defp read_settings do
    case File.read(".claude/settings.json") do
      {:ok, content} -> Jason.decode!(content)
      {:error, _} -> %{}
    end
  end

  defp hook_active?(name, settings) do
    hooks = Map.get(settings, "hooks", %{})

    Enum.any?(hooks, fn {_event, hook_list} ->
      Enum.any?(List.wrap(hook_list), fn hook ->
        is_map(hook) and String.contains?(Map.get(hook, "command", ""), name)
      end)
    end)
  end

  defp print_hooks([]) do
    IO.puts("No hooks found in #{@hooks_dir}/")
  end

  defp print_hooks(hooks) do
    IO.puts("Available Hooks")
    IO.puts(String.duplicate("=", 30))

    Enum.each(hooks, fn hook ->
      IO.puts("  #{hook.name} (#{hook.path})")
    end)
  end

  defp print_status([]) do
    IO.puts("No hooks found.")
  end

  defp print_status(hooks) do
    IO.puts("Hook Status")
    IO.puts(String.duplicate("=", 40))

    Enum.each(hooks, fn hook ->
      indicator = if hook.active, do: "[active]", else: "[inactive]"
      IO.puts("  #{String.pad_trailing(hook.name, 25)} #{indicator}")
    end)
  end
end
