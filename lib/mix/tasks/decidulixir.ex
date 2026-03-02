defmodule Mix.Tasks.Decidulixir do
  @shortdoc "Decision graph CLI"
  @moduledoc """
  Run decidulixir commands.

      mix decidulixir <command> [args]

  Run `mix decidulixir help` for available commands.
  """

  use Mix.Task

  @impl true
  def run([]), do: start_and(fn -> Decidulixir.CLI.help() end)
  def run(["help" | _]), do: start_and(fn -> Decidulixir.CLI.help() end)
  def run([command | argv]), do: start_and(fn -> Decidulixir.CLI.execute(command, argv) end)

  defp start_and(fun) do
    Mix.Task.run("app.start")
    fun.()
  end
end
