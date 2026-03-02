defmodule Decidulixir.CLI.GitPort do
  @moduledoc """
  Supervised port for git commands.

  Replaces System.cmd with explicit Port management under the CLI supervisor.
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec cmd([String.t()]) :: {:ok, String.t()} | {:error, String.t()}
  def cmd(args) do
    GenServer.call(__MODULE__, {:cmd, args}, :infinity)
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_call({:cmd, args}, _from, state) do
    {:reply, run_port(args), state}
  end

  defp run_port(args) do
    exe = System.find_executable("git") || "git"

    port =
      Port.open({:spawn_executable, exe}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:args, args}
      ])

    collect(port, [])
  end

  defp collect(port, acc) do
    receive do
      {^port, {:data, data}} ->
        collect(port, [data | acc])

      {^port, {:exit_status, 0}} ->
        {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary() |> String.trim()}

      {^port, {:exit_status, _code}} ->
        {:error, acc |> Enum.reverse() |> IO.iodata_to_binary() |> String.trim()}
    end
  end
end
