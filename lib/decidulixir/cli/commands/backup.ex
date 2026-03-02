defmodule Decidulixir.CLI.Commands.Backup do
  @moduledoc "Export the full decision graph to a JSON backup file."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.Graph

  @impl true
  def name, do: "backup"

  @impl true
  def description, do: "Backup graph to JSON: backup [-o PATH]"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [output: :string],
        aliases: [o: :output]
      )

    %{output: opts[:output]}
  end

  @impl true
  def execute(%{output: nil}) do
    dir = ".deciduous/backups"
    File.mkdir_p!(dir)
    ts = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(~r/[^0-9]/, "")
    path = Path.join(dir, "backup-#{ts}.json")
    write_backup(path)
  end

  def execute(%{output: path}) do
    path |> Path.dirname() |> File.mkdir_p!()
    write_backup(path)
  end

  defp write_backup(path) do
    graph = Graph.get_graph()
    stats = Graph.graph_stats()

    data = %{
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      stats: stats,
      nodes: graph.nodes,
      edges: graph.edges
    }

    File.write!(path, Jason.encode!(data, pretty: true))

    Logger.info("Backup saved to #{path} (#{stats.nodes} nodes, #{stats.edges} edges)")

    :ok
  end
end
