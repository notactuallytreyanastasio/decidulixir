defmodule Decidulixir.CLI.Commands.Tag do
  @moduledoc "Add, remove, and list tags on decision graph nodes."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.Graph

  @impl true
  def name, do: "tag"

  @impl true
  def description, do: "Manage node tags: tag add|remove|list"

  @impl true
  def parse(argv) do
    {opts, args, _invalid} =
      OptionParser.parse(argv,
        strict: [node: :integer, json: :boolean],
        aliases: [n: :node]
      )

    %{
      subcommand: List.first(args),
      node_id: opts[:node] || parse_int(Enum.at(args, 1)),
      tag: Enum.at(args, 2),
      json: opts[:json] || false
    }
  end

  @impl true
  def execute(%{subcommand: "add", node_id: id, tag: tag})
      when is_integer(id) and is_binary(tag) do
    case Graph.get_node(id) do
      nil ->
        Logger.error("Node #{id} not found")
        {:error, "not found"}

      node ->
        tags = get_tags(node) |> add_tag(tag)
        metadata = Map.put(node.metadata || %{}, "tags", tags)

        case Graph.update_node(node, %{metadata: metadata}) do
          {:ok, _} ->
            Logger.info("Tagged node #{id} with \"#{tag}\"")
            :ok

          {:error, cs} ->
            Logger.error("Failed: #{inspect(cs.errors)}")
            {:error, "update failed"}
        end
    end
  end

  def execute(%{subcommand: "remove", node_id: id, tag: tag})
      when is_integer(id) and is_binary(tag) do
    case Graph.get_node(id) do
      nil ->
        Logger.error("Node #{id} not found")
        {:error, "not found"}

      node ->
        tags = get_tags(node) |> List.delete(tag)
        metadata = Map.put(node.metadata || %{}, "tags", tags)

        case Graph.update_node(node, %{metadata: metadata}) do
          {:ok, _} ->
            Logger.info("Removed tag \"#{tag}\" from node #{id}")
            :ok

          {:error, cs} ->
            Logger.error("Failed: #{inspect(cs.errors)}")
            {:error, "update failed"}
        end
    end
  end

  def execute(%{subcommand: "list", node_id: id, json: json}) when is_integer(id) do
    case Graph.get_node(id) do
      nil ->
        Logger.error("Node #{id} not found")
        {:error, "not found"}

      node ->
        tags = get_tags(node)
        if json, do: IO.puts(Jason.encode!(tags)), else: print_tags(tags, id)
        :ok
    end
  end

  def execute(%{subcommand: "list", node_id: nil, json: json}) do
    tag_map = collect_all_tags()

    if json do
      IO.puts(Jason.encode!(tag_map, pretty: true))
    else
      print_all_tags(tag_map)
    end

    :ok
  end

  def execute(%{subcommand: nil}) do
    Logger.error("Usage: tag add|remove|list <node_id> [tag]")
    {:error, "missing arguments"}
  end

  def execute(%{subcommand: sub}) when sub in ["add", "remove"] do
    Logger.error("Usage: tag #{sub} <node_id> <tag>")
    {:error, "missing arguments"}
  end

  def execute(%{subcommand: sub}) do
    Logger.error("Unknown subcommand: #{sub}. Use add, remove, or list.")
    {:error, "unknown subcommand"}
  end

  defp get_tags(%{metadata: %{"tags" => tags}}) when is_list(tags), do: tags
  defp get_tags(_), do: []

  defp add_tag(tags, tag) do
    if tag in tags, do: tags, else: tags ++ [tag]
  end

  defp collect_all_tags do
    Graph.list_nodes()
    |> Enum.reduce(%{}, fn node, acc ->
      tags = get_tags(node)

      Enum.reduce(tags, acc, fn tag, inner ->
        Map.update(inner, tag, [node.id], &[node.id | &1])
      end)
    end)
    |> Map.new(fn {tag, ids} -> {tag, Enum.reverse(ids)} end)
  end

  defp print_tags([], id), do: IO.puts("Node #{id} has no tags.")

  defp print_tags(tags, id) do
    IO.puts("Tags for node #{id}:")
    Enum.each(tags, fn tag -> IO.puts("  #{tag}") end)
  end

  defp print_all_tags(tag_map) when map_size(tag_map) == 0 do
    IO.puts("No tags found.")
  end

  defp print_all_tags(tag_map) do
    IO.puts("Tags")
    IO.puts(String.duplicate("=", 30))

    tag_map
    |> Enum.sort_by(fn {tag, _} -> tag end)
    |> Enum.each(fn {tag, ids} ->
      IO.puts("  #{String.pad_trailing(tag, 20)} (#{length(ids)} node(s))")
    end)
  end

  defp parse_int(nil), do: nil

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> nil
    end
  end
end
