defmodule Decidulixir.CLI.Commands.Archaeology do
  @moduledoc "Mine git history to create decision graph nodes from commits."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.CLI.GitPort
  alias Decidulixir.Graph

  @impl true
  def name, do: "archaeology"

  @impl true
  def description, do: "Mine git history for decisions: archaeology [--since DATE]"

  @impl true
  def parse(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [
          since: :string,
          branch: :string,
          dry_run: :boolean,
          json: :boolean,
          limit: :integer
        ],
        aliases: [s: :since, b: :branch, n: :limit]
      )

    %{
      since: opts[:since],
      branch: opts[:branch],
      dry_run: opts[:dry_run] || false,
      json: opts[:json] || false,
      limit: opts[:limit] || 50
    }
  end

  @impl true
  def execute(config) do
    case fetch_commits(config) do
      {:ok, commits} ->
        entries = parse_commits(commits, config)

        if config.dry_run do
          show_dry_run(entries, config.json)
        else
          create_nodes(entries, config)
        end

      {:error, reason} ->
        Logger.error("Failed to read git log: #{reason}")
        {:error, "git log failed"}
    end
  end

  defp fetch_commits(config) do
    args = ["log", "--oneline", "--no-merges", "--format=%H|%h|%s|%ai"]
    args = if config.since, do: args ++ ["--since=#{config.since}"], else: args
    args = if config.branch, do: args ++ [config.branch], else: args
    args = args ++ ["-n", to_string(config.limit)]

    GitPort.cmd(args)
  end

  defp parse_commits(output, _config) do
    output
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_commit_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_commit_line(line) do
    case String.split(line, "|", parts: 4) do
      [full_sha, short_sha, message, date] ->
        {type, title} = classify_commit(message)

        %{
          sha: String.trim(full_sha),
          short_sha: String.trim(short_sha),
          message: String.trim(message),
          date: String.trim(date),
          node_type: type,
          title: title
        }

      _ ->
        nil
    end
  end

  defp classify_commit(message) do
    cond do
      String.starts_with?(message, "feat:") ->
        {:action, String.trim_leading(message, "feat:") |> String.trim()}

      String.starts_with?(message, "fix:") ->
        {:action, String.trim_leading(message, "fix:") |> String.trim()}

      String.starts_with?(message, "refactor:") ->
        {:action, String.trim_leading(message, "refactor:") |> String.trim()}

      String.starts_with?(message, "docs:") ->
        {:observation, String.trim_leading(message, "docs:") |> String.trim()}

      String.starts_with?(message, "test:") ->
        {:action, String.trim_leading(message, "test:") |> String.trim()}

      true ->
        {:action, message}
    end
  end

  defp show_dry_run(entries, true) do
    IO.puts(Jason.encode!(entries, pretty: true))
    :ok
  end

  defp show_dry_run(entries, false) do
    IO.puts("Archaeology Dry Run")
    IO.puts(String.duplicate("=", 50))
    IO.puts("Would create #{length(entries)} node(s):\n")

    Enum.each(entries, fn entry ->
      IO.puts("  [#{entry.node_type}] #{entry.title} (#{entry.short_sha}, #{entry.date})")
    end)

    :ok
  end

  defp create_nodes(entries, config) do
    results =
      Enum.map(entries, fn entry ->
        attrs = %{
          node_type: entry.node_type,
          title: entry.title,
          metadata: %{
            "commit" => entry.short_sha,
            "date" => entry.date,
            "branch" => config[:git_branch]
          }
        }

        case Graph.create_node(attrs) do
          {:ok, node} ->
            Logger.info("Created #{node.node_type} node #{node.id}: #{node.title}")
            {:ok, node}

          {:error, cs} ->
            Logger.error("Failed to create node: #{inspect(cs.errors)}")
            {:error, entry}
        end
      end)

    created = Enum.count(results, &match?({:ok, _}, &1))

    if config.json do
      nodes =
        Enum.flat_map(results, fn
          {:ok, n} -> [n]
          _ -> []
        end)

      IO.puts(Jason.encode!(nodes, pretty: true))
    else
      IO.puts("\nCreated #{created} node(s) from #{length(entries)} commit(s)")
    end

    :ok
  end
end
