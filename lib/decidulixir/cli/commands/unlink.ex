defmodule Decidulixir.CLI.Commands.Unlink do
  @moduledoc "Remove edges between two nodes."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.Graph

  @impl true
  def name, do: "unlink"

  @impl true
  def description, do: "Remove edge: unlink <from_id> <to_id>"

  @impl true
  def parse(argv) do
    {_opts, args, _invalid} = OptionParser.parse(argv, strict: [])

    %{
      from: parse_int(Enum.at(args, 0)),
      to: parse_int(Enum.at(args, 1))
    }
  end

  @impl true
  def execute(%{from: nil}) do
    Logger.error("Usage: unlink <from_id> <to_id>")
    {:error, "missing arguments"}
  end

  def execute(%{from: from_id, to: to_id}) when is_integer(from_id) and is_integer(to_id) do
    {:ok, count} = Graph.delete_edge(from_id, to_id)
    log_result(from_id, to_id, count)
    :ok
  end

  def execute(_config) do
    Logger.error("IDs must be integers")
    {:error, "invalid IDs"}
  end

  defp log_result(from, to, 0), do: Logger.warning("No edges found between #{from} and #{to}")
  defp log_result(from, to, n), do: Logger.info("Removed #{n} edge(s) between #{from} and #{to}")

  defp parse_int(nil), do: nil
  defp parse_int(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> {:error, str}
    end
  end
end
