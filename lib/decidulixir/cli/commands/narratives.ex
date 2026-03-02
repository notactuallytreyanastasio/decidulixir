defmodule Decidulixir.CLI.Commands.Narratives do
  @moduledoc "Follow edge chains to produce decision narratives."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.Graph
  alias Decidulixir.Graph.Traversal

  @impl true
  def name, do: "narratives"

  @impl true
  def description, do: "Show decision narrative: narratives <node_id>"

  @impl true
  def parse(argv) do
    {opts, args, _invalid} =
      OptionParser.parse(argv,
        strict: [depth: :integer, json: :boolean, direction: :string],
        aliases: [d: :depth]
      )

    %{
      node_id: parse_int(List.first(args)),
      depth: opts[:depth] || 10,
      json: opts[:json] || false,
      direction: parse_direction(opts[:direction])
    }
  end

  @impl true
  def execute(%{node_id: nil}) do
    Logger.error("Usage: narratives <node_id> [--depth N] [--json]")
    {:error, "missing arguments"}
  end

  def execute(%{node_id: id, direction: direction, depth: depth, json: json})
      when is_integer(id) do
    case Graph.get_node(id) do
      nil ->
        Logger.error("Node #{id} not found")
        {:error, "not found"}

      _node ->
        chain = build_narrative(id, direction, depth)

        if json do
          IO.puts(Jason.encode!(chain, pretty: true))
        else
          print_narrative(chain)
        end

        :ok
    end
  end

  defp build_narrative(start_id, direction, max_depth) do
    nodes = Traversal.bfs(start_id, direction)
    nodes |> Enum.take(max_depth) |> Enum.map(&narrative_entry/1)
  end

  defp narrative_entry(node) do
    %{
      id: node.id,
      type: node.node_type,
      title: node.title,
      status: node.status,
      branch: (node.metadata || %{})["branch"],
      commit: (node.metadata || %{})["commit"]
    }
  end

  defp print_narrative([]) do
    IO.puts("No nodes in narrative chain.")
  end

  defp print_narrative(entries) do
    IO.puts("Decision Narrative")
    IO.puts(String.duplicate("=", 50))

    entries
    |> Enum.with_index(1)
    |> Enum.each(fn {entry, idx} ->
      prefix = if idx == length(entries), do: "`-- ", else: "|-- "
      type_label = entry.type |> to_string() |> String.upcase()
      commit_info = if entry.commit, do: " [#{entry.commit}]", else: ""
      IO.puts("  #{prefix}#{idx}. [#{type_label}] #{entry.title}#{commit_info}")
    end)

    IO.puts("")
    IO.puts("  #{length(entries)} node(s) in chain")
  end

  defp parse_direction("incoming"), do: :incoming
  defp parse_direction("both"), do: :both
  defp parse_direction(_), do: :outgoing

  defp parse_int(nil), do: nil

  defp parse_int(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> nil
    end
  end
end
