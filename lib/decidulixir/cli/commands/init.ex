defmodule Decidulixir.CLI.Commands.Init do
  @moduledoc "Initialize decidulixir in the current project."

  @behaviour Decidulixir.CLI.Command

  require Logger

  @impl true
  def name, do: "init"

  @impl true
  def description, do: "Initialize project: init [--claude] [--opencode] [--windsurf]"

  @impl true
  def parse(argv) do
    {opts, args, _invalid} =
      OptionParser.parse(argv,
        strict: [claude: :boolean, opencode: :boolean, windsurf: :boolean],
        aliases: [c: :claude, o: :opencode, w: :windsurf]
      )

    %{args: args, opts: opts}
  end

  @impl true
  def execute(%{opts: opts}) do
    backends = build_backends(opts)

    case Decidulixir.Init.init_project(backends: backends) do
      :ok ->
        :ok

      {:error, msg} ->
        Logger.error(msg)
        {:error, msg}
    end
  end

  defp build_backends(opts) do
    backends = []
    backends = if opts[:claude], do: [:claude | backends], else: backends
    backends = if opts[:opencode], do: [:opencode | backends], else: backends
    backends = if opts[:windsurf], do: [:windsurf | backends], else: backends

    # Default to Claude if nothing specified
    if backends == [], do: [:claude], else: Enum.reverse(backends)
  end
end
