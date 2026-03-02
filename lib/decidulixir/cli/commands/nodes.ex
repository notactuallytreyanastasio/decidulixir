defmodule Decidulixir.CLI.Commands.Nodes do
  @moduledoc "List all nodes with optional filters."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.CLI.Formatter
  alias Decidulixir.Graph

  @impl true
  def name, do: "nodes"

  @impl true
  def description, do: "List nodes: nodes [--status S] [--branch B] [--search Q]"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [
          status: :string,
          branch: :string,
          search: :string,
          type: :string,
          limit: :integer,
          json: :boolean
        ],
        aliases: [s: :status, b: :branch, q: :search, t: :type, n: :limit]
      )

    %{
      status: opts[:status],
      branch: opts[:branch],
      search: opts[:search],
      type: opts[:type],
      limit: opts[:limit],
      json: opts[:json] || false
    }
  end

  @impl true
  def execute(%{json: true} = config) do
    nodes = config |> to_filters() |> Graph.list_nodes()
    IO.puts(Jason.encode!(nodes, pretty: true))
    :ok
  end

  def execute(config) do
    config |> to_filters() |> Graph.list_nodes() |> print_table()
  end

  defp print_table([]) do
    Logger.info("No nodes found.")
    :ok
  end

  defp print_table(nodes) do
    IO.puts("ID     Type         Status     Title")
    IO.puts(String.duplicate("-", 70))
    Enum.each(nodes, fn node -> IO.puts(Formatter.format_node(node)) end)
    Logger.info("#{length(nodes)} node(s)")
    :ok
  end

  defp to_filters(config) do
    []
    |> maybe_filter(:status, config.status, &String.to_existing_atom/1)
    |> maybe_filter(:node_type, config.type, &String.to_existing_atom/1)
    |> maybe_filter(:branch, config.branch, & &1)
    |> maybe_filter(:search, config.search, & &1)
    |> maybe_filter(:limit, config.limit, & &1)
  end

  defp maybe_filter(filters, _key, nil, _transform), do: filters
  defp maybe_filter(filters, key, val, transform), do: [{key, transform.(val)} | filters]
end
