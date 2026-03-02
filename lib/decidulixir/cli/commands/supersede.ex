defmodule Decidulixir.CLI.Commands.Supersede do
  @moduledoc "Mark a node as superseded by another."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.Graph

  @impl true
  def name, do: "supersede"

  @impl true
  def description, do: "Supersede: supersede <old_id> <new_id> [-r rationale]"

  @impl true
  def parse(argv) do
    {opts, args, _invalid} =
      OptionParser.parse(argv,
        strict: [rationale: :string],
        aliases: [r: :rationale]
      )

    rationale = opts[:rationale] || args |> Enum.drop(2) |> Enum.join(" ")

    %{
      old_id: parse_int(Enum.at(args, 0)),
      new_id: parse_int(Enum.at(args, 1)),
      rationale: if(rationale == "", do: "superseded", else: rationale)
    }
  end

  @impl true
  def execute(%{old_id: nil}) do
    Logger.error("Usage: supersede <old_id> <new_id> [-r rationale]")
    {:error, "missing arguments"}
  end

  def execute(%{new_id: nil}) do
    Logger.error("Usage: supersede <old_id> <new_id> [-r rationale]")
    {:error, "missing arguments"}
  end

  def execute(%{old_id: old_id, new_id: new_id, rationale: rationale})
      when is_integer(old_id) and is_integer(new_id) do
    case Graph.supersede(old_id, new_id, rationale) do
      {:ok, result} ->
        Logger.info("Node #{old_id} superseded by #{new_id} (edge #{result.edge.id})")
        :ok

      {:error, :old_node, :not_found, _} ->
        Logger.error("Node #{old_id} not found")
        {:error, "not found"}

      {:error, _step, reason, _} ->
        Logger.error("Supersede failed: #{inspect(reason)}")
        {:error, "supersede failed"}
    end
  end

  def execute(_config) do
    Logger.error("IDs must be integers")
    {:error, "invalid IDs"}
  end

  defp parse_int(nil), do: nil

  defp parse_int(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> {:error, str}
    end
  end
end
