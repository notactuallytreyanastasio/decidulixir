defmodule Decidulixir.CLI.Commands.Themes do
  @moduledoc "List and set graph viewer themes."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @available_themes ~w(default dark light high-contrast)

  @impl true
  def name, do: "themes"

  @impl true
  def description, do: "Manage themes: themes list|set|current"

  @impl true
  def parse(argv) do
    {opts, args, _invalid} =
      OptionParser.parse(argv, strict: [json: :boolean])

    %{
      subcommand: List.first(args) || "list",
      theme: Enum.at(args, 1),
      json: opts[:json] || false
    }
  end

  @impl true
  def execute(%{subcommand: "list", json: true}) do
    current = read_current_theme()
    data = Enum.map(@available_themes, fn t -> %{name: t, active: t == current} end)
    IO.puts(Jason.encode!(data, pretty: true))
    :ok
  end

  def execute(%{subcommand: "list"}) do
    current = read_current_theme()
    IO.puts("Available Themes")
    IO.puts(String.duplicate("=", 30))

    Enum.each(@available_themes, fn theme ->
      marker = if theme == current, do: " (active)", else: ""
      IO.puts("  #{theme}#{marker}")
    end)

    :ok
  end

  def execute(%{subcommand: "current", json: true}) do
    IO.puts(Jason.encode!(%{theme: read_current_theme()}))
    :ok
  end

  def execute(%{subcommand: "current"}) do
    IO.puts("Current theme: #{read_current_theme()}")
    :ok
  end

  def execute(%{subcommand: "set", theme: nil}) do
    Logger.error("Usage: themes set <theme_name>")
    {:error, "missing arguments"}
  end

  def execute(%{subcommand: "set", theme: theme}) do
    if theme in @available_themes do
      write_theme(theme)
      Logger.info("Theme set to: #{theme}")
      :ok
    else
      Logger.error("Unknown theme: #{theme}. Available: #{Enum.join(@available_themes, ", ")}")

      {:error, "unknown theme"}
    end
  end

  def execute(%{subcommand: sub}) do
    Logger.error("Unknown subcommand: #{sub}. Use list, set, or current.")
    {:error, "unknown subcommand"}
  end

  defp read_current_theme do
    case File.read(".deciduous/theme") do
      {:ok, theme} -> String.trim(theme)
      {:error, _} -> "default"
    end
  end

  defp write_theme(theme) do
    File.mkdir_p!(".deciduous")
    File.write!(".deciduous/theme", theme)
  end
end
