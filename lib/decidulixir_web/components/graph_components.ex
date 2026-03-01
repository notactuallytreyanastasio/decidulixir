defmodule DecidulixirWeb.GraphComponents do
  @moduledoc """
  Reusable UI components for decision graph display.
  """
  use Phoenix.Component

  attr :node, :map, required: true
  attr :class, :string, default: ""

  def node_card(assigns) do
    ~H"""
    <div class={"card bg-base-200 shadow-sm #{@class}"}>
      <div class="card-body p-4">
        <div class="flex items-center gap-2">
          <.node_badge type={@node.node_type} />
          <.status_badge status={@node.status} />
          <.confidence_badge metadata={@node.metadata} />
        </div>
        <h3 class="card-title text-sm mt-1">{@node.title}</h3>
        <p :if={@node.description} class="text-xs opacity-70 mt-1">
          {String.slice(@node.description, 0, 120)}
        </p>
        <div class="text-xs opacity-50 mt-1">
          #{@node.id}
          <span :if={@node.metadata["branch"]} class="ml-2">
            branch: {@node.metadata["branch"]}
          </span>
        </div>
      </div>
    </div>
    """
  end

  attr :type, :atom, required: true

  def node_badge(assigns) do
    ~H"""
    <span class={"badge badge-sm #{type_color(@type)}"}>{@type}</span>
    """
  end

  attr :status, :atom, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={"badge badge-sm badge-outline #{status_color(@status)}"}>{@status}</span>
    """
  end

  attr :metadata, :map, default: nil

  def confidence_badge(assigns) do
    confidence = get_in(assigns.metadata || %{}, ["confidence"])
    assigns = assign(assigns, :confidence, confidence)

    ~H"""
    <span :if={@confidence} class={"badge badge-sm #{confidence_color(@confidence)}"}>
      {@confidence}%
    </span>
    """
  end

  attr :edge, :map, required: true

  def edge_row(assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-sm py-1">
      <span class="font-mono text-xs">{@edge.from_node_id}</span>
      <span class="opacity-50">&rarr;</span>
      <span class="font-mono text-xs">{@edge.to_node_id}</span>
      <span class="badge badge-xs badge-ghost">{@edge.edge_type}</span>
      <span :if={@edge.rationale} class="text-xs opacity-60 italic">
        {@edge.rationale}
      </span>
    </div>
    """
  end

  attr :stats, :map, required: true

  def stats_panel(assigns) do
    ~H"""
    <div class="stats shadow w-full">
      <div class="stat">
        <div class="stat-title">Nodes</div>
        <div class="stat-value text-primary">{@stats.nodes}</div>
      </div>
      <div class="stat">
        <div class="stat-title">Edges</div>
        <div class="stat-value text-secondary">{@stats.edges}</div>
      </div>
      <div :for={{type, count} <- @stats.by_type} class="stat">
        <div class="stat-title">{type}</div>
        <div class="stat-value text-sm">{count}</div>
      </div>
    </div>
    """
  end

  defp type_color(:goal), do: "badge-primary"
  defp type_color(:decision), do: "badge-secondary"
  defp type_color(:option), do: "badge-info"
  defp type_color(:action), do: "badge-success"
  defp type_color(:outcome), do: "badge-warning"
  defp type_color(:observation), do: "badge-ghost"
  defp type_color(:revisit), do: "badge-error"
  defp type_color(_), do: "badge-ghost"

  defp status_color(:active), do: ""
  defp status_color(:completed), do: "text-success"
  defp status_color(:superseded), do: "text-warning opacity-60"
  defp status_color(:abandoned), do: "text-error opacity-60"
  defp status_color(:pending), do: "text-info"
  defp status_color(:rejected), do: "text-error"
  defp status_color(_), do: ""

  defp confidence_color(c) when c >= 80, do: "badge-success"
  defp confidence_color(c) when c >= 50, do: "badge-warning"
  defp confidence_color(_), do: "badge-error"
end
