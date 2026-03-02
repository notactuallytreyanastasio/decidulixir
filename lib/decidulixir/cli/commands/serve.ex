defmodule Decidulixir.CLI.Commands.Serve do
  @moduledoc "Start the Phoenix web viewer for the decision graph."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "serve"

  @impl true
  def description, do: "Start web viewer: serve [--port PORT]"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [port: :integer],
        aliases: [p: :port]
      )

    %{port: opts[:port] || 4000}
  end

  @impl true
  def execute(%{port: port}) do
    url = "http://localhost:#{port}"

    case check_endpoint() do
      :running ->
        Logger.info("Web viewer already running at #{url}")
        :ok

      :not_running ->
        Logger.info("Web viewer available at #{url}")
        Logger.info("The Phoenix endpoint is managed by the application supervisor.")
        Logger.info("Start with: mix phx.server")
        :ok
    end
  end

  defp check_endpoint do
    if Process.whereis(DecidulixirWeb.Endpoint) do
      :running
    else
      :not_running
    end
  end
end
