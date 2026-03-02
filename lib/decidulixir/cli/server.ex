defmodule Decidulixir.CLI.Server do
  @moduledoc """
  CLI command dispatcher.

  Plain module — no GenServer. Git context is fetched per call
  (it was refreshed every call anyway), and session state (active goal)
  lives in the `CLI.Session` Agent.

  Commands receive an enriched config map (their parsed opts + git context
  + active goal) and pattern match on it in function heads.
  """

  require Logger

  alias Decidulixir.CLI.Commands
  alias Decidulixir.CLI.Git
  alias Decidulixir.CLI.Session

  @commands %{
    "add" => Commands.Add,
    "link" => Commands.Link,
    "unlink" => Commands.Unlink,
    "delete" => Commands.Delete,
    "status" => Commands.Status,
    "prompt" => Commands.Prompt,
    "nodes" => Commands.Nodes,
    "edges" => Commands.Edges,
    "show" => Commands.Show,
    "graph" => Commands.Graph,
    "stats" => Commands.Stats,
    "supersede" => Commands.Supersede,
    "audit" => Commands.Audit,
    "doc" => Commands.Doc,
    "serve" => Commands.Serve,
    "sync" => Commands.Sync,
    "init" => Commands.Init,
    "update" => Commands.Update,
    "check-update" => Commands.CheckUpdate,
    "backup" => Commands.Backup,
    "pulse" => Commands.Pulse,
    "writeup" => Commands.Writeup,
    "themes" => Commands.Themes,
    "tag" => Commands.Tag,
    "hooks" => Commands.Hooks,
    "archaeology" => Commands.Archaeology,
    "narratives" => Commands.Narratives,
    "commands" => Commands.CommandsList
  }

  @spec execute(String.t(), [String.t()]) :: :ok | {:error, String.t()}
  def execute(command, argv) do
    case Map.get(@commands, command) do
      nil ->
        Logger.error("Unknown command: #{command}. Run 'mix decidulixir help'.")
        {:error, "unknown command"}

      module ->
        config = argv |> module.parse() |> enrich()

        case module.execute(config) do
          {:ok, updates} ->
            apply_updates(updates)
            :ok

          :ok ->
            :ok

          {:error, _} = err ->
            err
        end
    end
  end

  @spec commands() :: %{String.t() => module()}
  def commands, do: @commands

  defp enrich(config) do
    config
    |> Map.put_new(:git_branch, Git.branch())
    |> Map.put_new(:git_commit, Git.commit())
    |> Map.put_new(:active_goal, Session.active_goal())
  end

  defp apply_updates(updates) do
    case Map.get(updates, :active_goal) do
      nil -> :ok
      goal_id -> Session.set_active_goal(goal_id)
    end
  end
end
