defmodule Decidulixir.CLI.Commands.Doc do
  @moduledoc "Attach, list, show, and detach documents on decision graph nodes."

  @behaviour Decidulixir.CLI.Command

  require Logger

  import Ecto.Query

  alias Decidulixir.Graph
  alias Decidulixir.Graph.GraphDocument
  alias Decidulixir.Repo

  @storage_dir ".deciduous/documents"

  @impl true
  def name, do: "doc"

  @impl true
  def description, do: "Manage documents: doc attach|list|show|detach"

  @impl true
  def parse(argv) do
    {opts, args, _invalid} =
      OptionParser.parse(argv,
        strict: [description: :string, json: :boolean],
        aliases: [d: :description]
      )

    %{
      subcommand: List.first(args),
      args: Enum.drop(args, 1),
      description: opts[:description],
      json: opts[:json] || false
    }
  end

  @impl true
  def execute(%{subcommand: "attach", args: [node_id_str, file_path | _]} = config) do
    with {node_id, ""} <- Integer.parse(node_id_str),
         %{} = node <- Graph.get_node(node_id),
         {:ok, stat} <- File.stat(file_path),
         {:ok, content} <- File.read(file_path) do
      hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
      filename = Path.basename(file_path)
      storage_name = "#{hash}_#{filename}"
      storage_path = Path.join(@storage_dir, storage_name)

      File.mkdir_p!(@storage_dir)
      File.copy!(file_path, storage_path)

      attrs = %{
        node_id: node.id,
        node_change_id: node.change_id,
        content_hash: hash,
        original_filename: filename,
        storage_filename: storage_name,
        storage_backend: "local",
        mime_type: MIME.from_path(file_path),
        file_size: stat.size,
        description: config.description
      }

      case %GraphDocument{} |> GraphDocument.changeset(attrs) |> Repo.insert() do
        {:ok, doc} ->
          Logger.info("Attached #{filename} to node #{node.id} (doc #{doc.id})")
          :ok

        {:error, cs} ->
          Logger.error("Failed to attach: #{inspect(cs.errors)}")
          {:error, "attach failed"}
      end
    else
      nil ->
        Logger.error("Node not found")
        {:error, "not found"}

      :error ->
        Logger.error("Invalid node ID")
        {:error, "invalid ID"}

      {:error, reason} ->
        Logger.error("File error: #{inspect(reason)}")
        {:error, "file error"}
    end
  end

  def execute(%{subcommand: "list", args: [], json: json}) do
    docs =
      GraphDocument
      |> where([d], is_nil(d.detached_at))
      |> order_by([d], asc: d.id)
      |> Repo.all()

    if json do
      IO.puts(Jason.encode!(docs, pretty: true))
    else
      print_docs(docs)
    end

    :ok
  end

  def execute(%{subcommand: "list", args: [node_id_str | _], json: json}) do
    case Integer.parse(node_id_str) do
      {node_id, ""} ->
        docs = Graph.list_documents(node_id)

        if json do
          IO.puts(Jason.encode!(docs, pretty: true))
        else
          print_docs(docs)
        end

        :ok

      _ ->
        Logger.error("Invalid node ID: #{node_id_str}")
        {:error, "invalid ID"}
    end
  end

  def execute(%{subcommand: "show", args: [doc_id_str | _], json: json}) do
    with {doc_id, ""} <- Integer.parse(doc_id_str),
         %GraphDocument{} = doc <- Repo.get(GraphDocument, doc_id) do
      if json, do: IO.puts(Jason.encode!(doc, pretty: true)), else: print_doc_detail(doc)
      :ok
    else
      nil ->
        Logger.error("Document not found")
        {:error, "not found"}

      :error ->
        Logger.error("Invalid document ID: #{doc_id_str}")
        {:error, "invalid ID"}

      _ ->
        Logger.error("Invalid document ID: #{doc_id_str}")
        {:error, "invalid ID"}
    end
  end

  def execute(%{subcommand: "detach", args: [doc_id_str | _]}) do
    case Integer.parse(doc_id_str) do
      {doc_id, ""} ->
        case Repo.get(GraphDocument, doc_id) do
          nil ->
            Logger.error("Document #{doc_id} not found")
            {:error, "not found"}

          doc ->
            now = DateTime.utc_now() |> DateTime.truncate(:second)

            doc
            |> Ecto.Changeset.change(detached_at: now)
            |> Repo.update!()

            Logger.info("Detached document #{doc_id}")
            :ok
        end

      _ ->
        Logger.error("Invalid document ID: #{doc_id_str}")
        {:error, "invalid ID"}
    end
  end

  def execute(%{subcommand: nil}) do
    Logger.error("Usage: doc attach|list|show|detach [args]")
    {:error, "missing arguments"}
  end

  def execute(%{subcommand: "attach"}) do
    Logger.error("Usage: doc attach <node_id> <file_path> [-d description]")
    {:error, "missing arguments"}
  end

  def execute(%{subcommand: sub}) do
    Logger.error("Unknown subcommand: #{sub}")
    {:error, "unknown subcommand"}
  end

  defp print_docs([]), do: IO.puts("No documents found.")

  defp print_docs(docs) do
    IO.puts("ID     Node   Filename                 Size")
    IO.puts(String.duplicate("-", 60))

    Enum.each(docs, fn doc ->
      id = String.pad_leading(to_string(doc.id), 5)
      node = String.pad_leading(to_string(doc.node_id), 5)
      name = String.pad_trailing(doc.original_filename, 24)
      size = format_size(doc.file_size)
      IO.puts("#{id}  #{node}  #{name} #{size}")
    end)
  end

  defp print_doc_detail(doc) do
    IO.puts("Document #{doc.id}")
    IO.puts(String.duplicate("=", 40))
    IO.puts("  Node:     #{doc.node_id}")
    IO.puts("  File:     #{doc.original_filename}")
    IO.puts("  Size:     #{format_size(doc.file_size)}")
    IO.puts("  MIME:     #{doc.mime_type}")
    IO.puts("  Hash:     #{doc.content_hash}")
    IO.puts("  Backend:  #{doc.storage_backend}")
    if doc.description, do: IO.puts("  Desc:     #{doc.description}")
    IO.puts("  Attached: #{doc.attached_at}")
    if doc.detached_at, do: IO.puts("  Detached: #{doc.detached_at}")
  end

  defp format_size(nil), do: "?"
  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
