defmodule Decidulixir.CLI.Server do
  @moduledoc """
  GenServer controlling all CLI interactions.

  Holds two contexts:
  - **git** — current branch, commit, repo state (refreshed per command)
  - **graph** — active goal, session state (persisted across commands)

  Commands receive an enriched config hash (their parsed opts + both contexts)
  and pattern match on it in function heads.
  """

  use GenServer

  require Logger

  alias Decidulixir.CLI.Commands
  alias Decidulixir.CLI.GitPort

  @type git_context :: %{branch: String.t() | nil, commit: String.t() | nil}
  @type graph_context :: %{active_goal: integer() | nil}

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

  # ── Public API ──────────────────────────────────────────

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec execute(String.t(), [String.t()]) :: :ok | {:error, String.t()}
  def execute(command, argv) do
    GenServer.call(__MODULE__, {:execute, command, argv}, :infinity)
  end

  @spec commands() :: %{String.t() => module()}
  def commands, do: @commands

  # ── GenServer callbacks ─────────────────────────────────

  @impl true
  def init(_opts) do
    {:ok, %{git: refresh_git(), graph: %{active_goal: nil}}}
  end

  @impl true
  def handle_call({:execute, command, argv}, _from, state) do
    state = %{state | git: refresh_git()}

    case dispatch(command, argv, state) do
      {:ok, updates} ->
        {:reply, :ok, apply_updates(state, updates)}

      :ok ->
        {:reply, :ok, state}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  # ── Private ─────────────────────────────────────────────

  defp dispatch(command, argv, state) do
    case Map.get(@commands, command) do
      nil ->
        Logger.error("Unknown command: #{command}. Run 'mix decidulixir help'.")
        {:error, "unknown command"}

      module ->
        argv |> module.parse() |> enrich(state) |> module.execute()
    end
  end

  defp enrich(config, state) do
    config
    |> Map.put_new(:git_branch, state.git.branch)
    |> Map.put_new(:git_commit, state.git.commit)
    |> Map.put_new(:active_goal, state.graph.active_goal)
  end

  defp refresh_git do
    %{
      branch: git_value(["rev-parse", "--abbrev-ref", "HEAD"]),
      commit: git_value(["rev-parse", "--short", "HEAD"])
    }
  end

  defp git_value(args) do
    case GitPort.cmd(args) do
      {:ok, val} -> val
      {:error, _} -> nil
    end
  end

  defp apply_updates(state, updates) do
    Enum.reduce(updates, state, fn
      {:active_goal, id}, acc -> put_in(acc, [:graph, :active_goal], id)
      _, acc -> acc
    end)
  end
end
