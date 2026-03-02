defmodule Decidulixir.CLI.Supervisor do
  @moduledoc """
  Supervises CLI session state.

  Previously supervised `GitPort` (stateless GenServer) and `Server`
  (minimal-state GenServer). Now only supervises the `Session` Agent
  which tracks the active goal between commands.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Decidulixir.CLI.Session
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
