defmodule Decidulixir.CLI.Commands.Edges do
  @moduledoc "List all edges with optional filters."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.CLI.Formatter
  alias Decidulixir.Graph

  @impl true
  def name, do: "edges"

  @impl true
  def description, do: "List edges: edges [--type T]"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [type: :string, json: :boolean],
        aliases: [t: :type]
      )

    %{
      type: opts[:type],
      json: opts[:json] || false
    }
  end

  @impl true
  def execute(%{json: true} = config) do
    edges = config |> to_filters() |> Graph.list_edges()
    IO.puts(Jason.encode!(edges, pretty: true))
    :ok
  end

  def execute(config) do
    config |> to_filters() |> Graph.list_edges() |> print_table()
  end

  defp print_table([]) do
    Logger.info("No edges found.")
    :ok
  end

  defp print_table(edges) do
    IO.puts("ID     From -> To    Type         Rationale")
    IO.puts(String.duplicate("-", 60))
    Enum.each(edges, fn edge -> IO.puts(Formatter.format_edge(edge)) end)
    Logger.info("#{length(edges)} edge(s)")
    :ok
  end

  defp to_filters(%{type: nil}), do: []
  defp to_filters(%{type: t}), do: [edge_type: String.to_existing_atom(t)]
end
