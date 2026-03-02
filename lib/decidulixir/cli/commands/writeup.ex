defmodule Decidulixir.CLI.Commands.Writeup do
  @moduledoc "Generate markdown report from the decision graph."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.CLI.Formatter
  alias Decidulixir.Graph
  alias Decidulixir.Graph.Traversal

  @impl true
  def name, do: "writeup"

  @impl true
  def description, do: "Generate report from graph: writeup [--node ID] [-o FILE]"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [node: :integer, output: :string, json: :boolean],
        aliases: [n: :node, o: :output]
      )

    %{
      node_id: opts[:node],
      output: opts[:output],
      json: opts[:json] || false
    }
  end

  @impl true
  def execute(%{node_id: id, json: true}) do
    report = build_report(id)
    IO.puts(Jason.encode!(report, pretty: true))
    :ok
  end

  def execute(%{node_id: id, output: path}) when is_binary(path) do
    md = build_report(id) |> to_markdown()
    File.write!(path, md)
    Logger.info("Writeup saved to #{path}")
    :ok
  end

  def execute(%{node_id: id}) do
    IO.puts(build_report(id) |> to_markdown())
    :ok
  end

  defp build_report(nil) do
    graph = Graph.get_graph()
    nodes = graph.nodes
    build_sections(nodes)
  end

  defp build_report(id) do
    case Graph.get_node(id) do
      nil ->
        %{error: "Node #{id} not found", sections: %{}}

      _node ->
        nodes = Traversal.bfs(id, :outgoing)
        build_sections(nodes)
    end
  end

  defp build_sections(nodes) do
    grouped = Enum.group_by(nodes, & &1.node_type)

    %{
      goals: Enum.map(grouped[:goal] || [], &summary/1),
      options: Enum.map(grouped[:option] || [], &summary/1),
      decisions: Enum.map(grouped[:decision] || [], &summary/1),
      actions: Enum.map(grouped[:action] || [], &summary/1),
      outcomes: Enum.map(grouped[:outcome] || [], &summary/1),
      observations: Enum.map(grouped[:observation] || [], &summary/1),
      total_nodes: length(nodes)
    }
  end

  defp summary(node) do
    %{
      id: node.id,
      title: node.title,
      status: node.status,
      display: Formatter.format_node(node)
    }
  end

  defp to_markdown(report) do
    sections = [
      {"Goals", report.goals},
      {"Options Explored", report.options},
      {"Decisions Made", report.decisions},
      {"Actions Taken", report.actions},
      {"Outcomes", report.outcomes},
      {"Observations", report.observations}
    ]

    header = "# Decision Graph Report\n\n"
    summary = "**Total nodes:** #{report.total_nodes}\n\n"

    body =
      sections
      |> Enum.reject(fn {_, items} -> items == [] end)
      |> Enum.map_join("\n", fn {title, items} ->
        items_md = Enum.map_join(items, "\n", fn i -> "- #{i.display}" end)
        "## #{title}\n\n#{items_md}\n"
      end)

    header <> summary <> body
  end
end
