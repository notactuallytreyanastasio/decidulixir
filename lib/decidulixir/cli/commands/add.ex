defmodule Decidulixir.CLI.Commands.Add do
  @moduledoc "Add a new node to the decision graph."

  @behaviour Decidulixir.CLI.Command

  require Logger

  alias Decidulixir.CLI.Formatter
  alias Decidulixir.Graph
  alias Decidulixir.Graph.Metadata

  @valid_types ~w(goal decision option action outcome observation revisit)a
  @valid_type_strings Map.new(@valid_types, fn t -> {Atom.to_string(t), t} end)

  @impl true
  def name, do: "add"

  @impl true
  def description, do: "Add a node: add <type> \"title\" [options]"

  @impl true
  def parse(argv) do
    {opts, args, _invalid} =
      OptionParser.parse(argv,
        strict: [
          confidence: :integer,
          prompt: :string,
          files: :string,
          branch: :string,
          commit: :string,
          date: :string,
          description: :string,
          prompt_stdin: :boolean
        ],
        aliases: [c: :confidence, p: :prompt, f: :files, b: :branch, d: :description]
      )

    %{
      type: List.first(args),
      title: args |> Enum.drop(1) |> Enum.join(" "),
      confidence: opts[:confidence],
      prompt: opts[:prompt],
      files: opts[:files],
      branch: opts[:branch],
      commit: opts[:commit],
      description: opts[:description]
    }
  end

  @impl true
  def execute(%{type: nil}) do
    Logger.error("Usage: add <type> \"title\" [options]")
    {:error, "missing arguments"}
  end

  def execute(%{title: ""}) do
    Logger.error("Title is required: add <type> \"title\"")
    {:error, "missing title"}
  end

  def execute(%{type: type_str} = config) do
    case parse_type(type_str) do
      {:ok, type} -> create_node(type, config)
      :error -> unknown_type(type_str)
    end
  end

  defp create_node(type, %{title: title} = config) do
    metadata = build_metadata(config)
    attrs = build_attrs(type, title, metadata, config)

    case Graph.create_node(attrs) do
      {:ok, node} ->
        Logger.info("Created node #{node.id} (#{type}: \"#{title}\")")
        log_metadata(config, metadata)
        {:ok, goal_update(type, node)}

      {:error, changeset} ->
        Logger.error("Failed to create node: #{Formatter.format_changeset_errors(changeset)}")
        {:error, "create failed"}
    end
  end

  defp build_attrs(type, title, metadata, config) do
    base = %{node_type: type, title: title, metadata: metadata}

    case config[:description] do
      nil -> base
      desc -> Map.put(base, :description, desc)
    end
  end

  defp build_metadata(%{branch: nil, git_branch: git_branch} = config) do
    config
    |> take_metadata_opts()
    |> Metadata.build()
    |> maybe_set_branch(git_branch)
    |> maybe_set_commit(config[:commit])
  end

  defp build_metadata(%{branch: branch} = config) do
    config
    |> take_metadata_opts()
    |> Metadata.build()
    |> Metadata.set_branch(branch)
    |> maybe_set_commit(config[:commit])
  end

  defp take_metadata_opts(config) do
    config
    |> Map.take([:confidence, :prompt, :files])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp maybe_set_branch(meta, nil), do: meta
  defp maybe_set_branch(meta, branch), do: Metadata.set_branch(meta, branch)

  defp maybe_set_commit(meta, nil), do: meta
  defp maybe_set_commit(meta, ref), do: Metadata.set_commit(meta, ref)

  defp log_metadata(config, metadata) do
    if config.confidence, do: Logger.info("  confidence: #{config.confidence}%")
    if metadata["commit"], do: Logger.info("  commit: #{metadata["commit"]}")
    if metadata["branch"], do: Logger.info("  branch: #{metadata["branch"]}")
  end

  defp goal_update(:goal, node), do: %{active_goal: node.id}
  defp goal_update(_, _node), do: %{}

  defp unknown_type(type_str) do
    valid = @valid_types |> Enum.map_join(", ", &to_string/1)
    Logger.error("Unknown node type: #{type_str} (valid: #{valid})")
    {:error, "unknown type"}
  end

  defp parse_type(str) when is_binary(str) do
    case Map.fetch(@valid_type_strings, str) do
      {:ok, type} -> {:ok, type}
      :error -> :error
    end
  end
end
