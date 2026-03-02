defmodule Decidulixir.CLI.Commands.Graph do
  @moduledoc "Export the full decision graph as JSON."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.Graph

  @impl true
  def name, do: "graph"

  @impl true
  def description, do: "Export full graph as JSON"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [branch: :string, output: :string],
        aliases: [b: :branch, o: :output]
      )

    %{
      branch: opts[:branch],
      output: opts[:output]
    }
  end

  @impl true
  def execute(%{output: nil} = config) do
    data = build_graph(config)
    IO.puts(Jason.encode!(data, pretty: true))
    :ok
  end

  def execute(%{output: path} = config) do
    data = build_graph(config)
    File.write!(path, Jason.encode!(data, pretty: true))
    Logger.info("Graph exported to #{path}")
    :ok
  end

  defp build_graph(%{branch: nil}), do: graph_data([])
  defp build_graph(%{branch: branch}), do: graph_data(branch: branch)

  defp graph_data(filters) do
    graph = Graph.get_graph(filters)
    %{nodes: graph.nodes, edges: graph.edges, stats: Graph.graph_stats()}
  end
end
