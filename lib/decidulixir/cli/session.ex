defmodule Decidulixir.CLI.Session do
  @moduledoc """
  Stores CLI session state (active goal ID).

  An Agent is the correct OTP primitive here: we need state
  but no behavior. The previous GenServer (`CLI.Server`) combined
  stateless dispatch with minimal state tracking — this separates
  those concerns.
  """

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> nil end, name: __MODULE__)
  end

  @spec active_goal() :: integer() | nil
  def active_goal do
    Agent.get(__MODULE__, & &1)
  end

  @spec set_active_goal(integer()) :: :ok
  def set_active_goal(goal_id) do
    Agent.update(__MODULE__, fn _ -> goal_id end)
  end
end
