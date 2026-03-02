defmodule Decidulixir.CLI.Commands.Sync do
  @moduledoc "Export graph and git history for static deployment."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.CLI.GitPort
  alias Decidulixir.Graph

  @impl true
  def name, do: "sync"

  @impl true
  def description, do: "Export graph for deployment: sync [-o DIR]"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [output: :string],
        aliases: [o: :output]
      )

    %{output: opts[:output] || "docs"}
  end

  @impl true
  def execute(%{output: dir}) do
    File.mkdir_p!(dir)

    graph = Graph.get_graph()
    stats = Graph.graph_stats()

    graph_path = Path.join(dir, "graph-data.json")
    graph_data = %{nodes: graph.nodes, edges: graph.edges, stats: stats}
    File.write!(graph_path, Jason.encode!(graph_data, pretty: true))
    Logger.info("Exported graph to #{graph_path}")

    git_path = Path.join(dir, "git-history.json")
    git_data = build_git_history(graph.nodes)
    File.write!(git_path, Jason.encode!(git_data, pretty: true))
    Logger.info("Exported git history to #{git_path}")

    Logger.info("Sync complete: #{stats.nodes} nodes, #{stats.edges} edges")

    :ok
  end

  defp build_git_history(nodes) do
    nodes
    |> Enum.filter(fn n -> (n.metadata || %{})["commit"] != nil end)
    |> Enum.map(fn node ->
      commit = node.metadata["commit"]
      details = fetch_commit_details(commit)

      %{
        node_id: node.id,
        commit: commit,
        details: details
      }
    end)
  end

  defp fetch_commit_details(sha) do
    case GitPort.cmd(["log", "-1", "--format=%H|%an|%ai|%s", sha]) do
      {:ok, output} ->
        case String.split(output, "|", parts: 4) do
          [full_sha, author, date, message] ->
            %{sha: full_sha, author: author, date: date, message: message}

          _ ->
            %{sha: sha, error: "parse failed"}
        end

      {:error, _} ->
        %{sha: sha, error: "not found"}
    end
  end
end
