defmodule Decidulixir.CLI.Commands.Stats do
  @moduledoc "Show graph statistics."

  @behaviour Decidulixir.CLI.Command

  alias Decidulixir.Graph

  @impl true
  def name, do: "stats"

  @impl true
  def description, do: "Show graph statistics"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv, strict: [json: :boolean])

    %{json: opts[:json] || false}
  end

  @impl true
  def execute(%{json: true}) do
    IO.puts(
      Jason.encode!(%{totals: Graph.graph_stats(), by_type: Graph.node_counts_by_type()},
        pretty: true
      )
    )

    :ok
  end

  def execute(%{json: false}) do
    stats = Graph.graph_stats()
    counts = Graph.node_counts_by_type()

    IO.puts("Graph Statistics")
    IO.puts(String.duplicate("=", 30))
    IO.puts("  Total nodes: #{stats.nodes}")
    IO.puts("  Total edges: #{stats.edges}")
    IO.puts("")
    IO.puts("  By type:")

    counts
    |> Enum.sort_by(fn {_type, count} -> -count end)
    |> Enum.each(fn {type, count} ->
      IO.puts("    #{String.pad_trailing(to_string(type), 13)} #{count}")
    end)

    :ok
  end
end
