defmodule Decidulixir.CLI.Formatter do
  @moduledoc """
  Pure formatting functions for CLI output.

  Returns strings for nodes, edges, errors. Does not do any I/O itself
  — callers use Logger or IO.puts with the returned strings.
  """

  @doc "Formats a node as a single display line."
  @spec format_node(map()) :: String.t()
  def format_node(node) do
    confidence = format_confidence(node.metadata)
    id = String.pad_leading(to_string(node.id), 5)
    type = node.node_type |> to_string() |> String.pad_trailing(12)
    status = node.status |> to_string() |> String.pad_trailing(10)

    "#{id}   #{type} #{status} #{node.title}#{confidence}"
  end

  @doc "Formats an edge as a single display line."
  @spec format_edge(map()) :: String.t()
  def format_edge(edge) do
    id = String.pad_leading(to_string(edge.id), 5)
    from = String.pad_leading(to_string(edge.from_node_id), 5)
    to = String.pad_leading(to_string(edge.to_node_id), 5)
    type = edge.edge_type |> to_string() |> String.pad_trailing(12)
    rationale = if edge.rationale, do: " #{edge.rationale}", else: ""

    "#{id}   #{from} -> #{to}    #{type}#{rationale}"
  end

  @doc "Outputs pretty-printed JSON to stdout."
  @spec json(term()) :: :ok
  def json(data), do: data |> Jason.encode!(pretty: true) |> IO.puts()

  @doc "Formats changeset errors as a human-readable string."
  @spec format_changeset_errors(Ecto.Changeset.t()) :: String.t()
  def format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, val}, acc ->
        String.replace(acc, "%{#{key}}", to_string(val))
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
  end

  defp format_confidence(nil), do: ""
  defp format_confidence(%{"confidence" => c}), do: " [#{c}%]"
  defp format_confidence(_), do: ""
end
