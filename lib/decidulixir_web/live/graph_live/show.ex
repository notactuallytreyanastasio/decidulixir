defmodule DecidulixirWeb.GraphLive.Show do
  @moduledoc "Node detail view — shows a single node with its edges."
  use DecidulixirWeb, :live_view

  alias Decidulixir.Graph

  @impl true
  def mount(%{"id" => id_str}, _session, socket) do
    case Integer.parse(id_str) do
      {id, ""} ->
        case Graph.get_node(id) do
          nil ->
            {:ok, socket |> put_flash(:error, "Node not found") |> redirect(to: ~p"/graph")}

          node ->
            if connected?(socket) do
              Phoenix.PubSub.subscribe(Decidulixir.PubSub, "graph:updates")
            end

            socket =
              socket
              |> assign(:page_title, "Node #{node.id}: #{node.title}")
              |> assign(:node, node)
              |> assign(:incoming, Graph.edges_to(id))
              |> assign(:outgoing, Graph.edges_from(id))
              |> assign(:documents, Graph.list_documents(id))

            {:ok, socket}
        end

      _ ->
        {:ok, socket |> put_flash(:error, "Invalid node ID") |> redirect(to: ~p"/graph")}
    end
  end

  @impl true
  def handle_info({:graph_updated, _change}, socket) do
    node = Graph.get_node(socket.assigns.node.id)

    if node do
      socket =
        socket
        |> assign(:node, node)
        |> assign(:incoming, Graph.edges_to(node.id))
        |> assign(:outgoing, Graph.edges_from(node.id))

      {:noreply, socket}
    else
      {:noreply, socket |> put_flash(:info, "Node was deleted") |> redirect(to: ~p"/graph")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div class="flex items-center gap-2">
          <.link navigate={~p"/graph"} class="btn btn-ghost btn-sm">
            &larr; Back
          </.link>
          <h1 class="text-2xl font-bold">Node {@node.id}</h1>
        </div>

        <DecidulixirWeb.GraphComponents.node_card node={@node} />

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="card bg-base-200">
            <div class="card-body p-4">
              <h2 class="card-title text-sm">Details</h2>
              <dl class="text-sm space-y-1">
                <div class="flex gap-2">
                  <dt class="font-semibold opacity-70 w-24">Change ID:</dt>
                  <dd class="font-mono text-xs">{@node.change_id}</dd>
                </div>
                <div :if={@node.description} class="flex gap-2">
                  <dt class="font-semibold opacity-70 w-24">Description:</dt>
                  <dd>{@node.description}</dd>
                </div>
                <div class="flex gap-2">
                  <dt class="font-semibold opacity-70 w-24">Created:</dt>
                  <dd>{@node.inserted_at}</dd>
                </div>
                <div class="flex gap-2">
                  <dt class="font-semibold opacity-70 w-24">Updated:</dt>
                  <dd>{@node.updated_at}</dd>
                </div>
              </dl>
            </div>
          </div>

          <div :if={@node.metadata && @node.metadata != %{}} class="card bg-base-200">
            <div class="card-body p-4">
              <h2 class="card-title text-sm">Metadata</h2>
              <dl class="text-sm space-y-1">
                <div :for={{key, val} <- @node.metadata} class="flex gap-2">
                  <dt class="font-semibold opacity-70">{key}:</dt>
                  <dd class="font-mono text-xs">{inspect(val)}</dd>
                </div>
              </dl>
            </div>
          </div>
        </div>

        <div :if={@incoming != []} class="card bg-base-200">
          <div class="card-body p-4">
            <h2 class="card-title text-sm">Incoming Edges ({length(@incoming)})</h2>
            <div :for={edge <- @incoming} class="flex items-center gap-2 text-sm py-1">
              <.link navigate={~p"/graph/#{edge.from_node_id}"} class="link link-primary font-mono text-xs">
                {edge.from_node_id}
              </.link>
              <span class="opacity-50">&rarr;</span>
              <span class="font-mono text-xs">{@node.id}</span>
              <span class="badge badge-xs badge-ghost">{edge.edge_type}</span>
              <span :if={edge.rationale} class="text-xs opacity-60 italic">{edge.rationale}</span>
            </div>
          </div>
        </div>

        <div :if={@outgoing != []} class="card bg-base-200">
          <div class="card-body p-4">
            <h2 class="card-title text-sm">Outgoing Edges ({length(@outgoing)})</h2>
            <div :for={edge <- @outgoing} class="flex items-center gap-2 text-sm py-1">
              <span class="font-mono text-xs">{@node.id}</span>
              <span class="opacity-50">&rarr;</span>
              <.link navigate={~p"/graph/#{edge.to_node_id}"} class="link link-primary font-mono text-xs">
                {edge.to_node_id}
              </.link>
              <span class="badge badge-xs badge-ghost">{edge.edge_type}</span>
              <span :if={edge.rationale} class="text-xs opacity-60 italic">{edge.rationale}</span>
            </div>
          </div>
        </div>

        <div :if={@documents != []} class="card bg-base-200">
          <div class="card-body p-4">
            <h2 class="card-title text-sm">Documents ({length(@documents)})</h2>
            <div :for={doc <- @documents} class="text-sm py-1">
              <span class="font-mono">{doc.file_path}</span>
              <span :if={doc.description} class="opacity-60 ml-2">— {doc.description}</span>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
