defmodule Decidulixir.CLI.Commands.Link do
  @moduledoc "Create an edge between two nodes."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.CLI.Formatter
  alias Decidulixir.Graph

  @impl true
  def name, do: "link"

  @impl true
  def description, do: "Link nodes: link <from_id> <to_id> [-r rationale]"

  @impl true
  def parse(argv) do
    {opts, args, _invalid} =
      OptionParser.parse(argv,
        strict: [rationale: :string, edge_type: :string],
        aliases: [r: :rationale, t: :edge_type]
      )

    %{
      from: parse_int(Enum.at(args, 0)),
      to: parse_int(Enum.at(args, 1)),
      rationale: opts[:rationale],
      edge_type: opts[:edge_type]
    }
  end

  @impl true
  def execute(%{from: nil}) do
    Logger.error("Usage: link <from_id> <to_id> [-r rationale]")
    {:error, "missing arguments"}
  end

  def execute(%{to: nil}) do
    Logger.error("Usage: link <from_id> <to_id> [-r rationale]")
    {:error, "missing arguments"}
  end

  def execute(%{from: {:error, val}}) do
    Logger.error("Invalid from_id: #{val}. Must be integer.")
    {:error, "invalid ID"}
  end

  def execute(%{to: {:error, val}}) do
    Logger.error("Invalid to_id: #{val}. Must be integer.")
    {:error, "invalid ID"}
  end

  def execute(%{from: from_id, to: to_id} = config) when is_integer(from_id) and is_integer(to_id) do
    attrs = edge_attrs(config)

    case Graph.create_edge(from_id, to_id, attrs) do
      {:ok, edge} ->
        Logger.info("Created edge #{edge.id} (#{from_id} -> #{to_id} via #{edge.edge_type})")
        :ok

      {:error, changeset} ->
        Logger.error("Failed to create edge: #{Formatter.format_changeset_errors(changeset)}")
        {:error, "create edge failed"}
    end
  end

  defp edge_attrs(%{rationale: nil, edge_type: nil}), do: %{}
  defp edge_attrs(%{rationale: r, edge_type: nil}), do: %{rationale: r}
  defp edge_attrs(%{rationale: nil, edge_type: t}), do: %{edge_type: String.to_existing_atom(t)}
  defp edge_attrs(%{rationale: r, edge_type: t}), do: %{rationale: r, edge_type: String.to_existing_atom(t)}

  defp parse_int(nil), do: nil
  defp parse_int(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> {:error, str}
    end
  end
end
