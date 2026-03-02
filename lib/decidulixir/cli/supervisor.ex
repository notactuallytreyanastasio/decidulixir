defmodule Decidulixir.CLI.Supervisor do
  @moduledoc "Supervises CLI server and git port processes."

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Decidulixir.CLI.GitPort,
      Decidulixir.CLI.Server
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
