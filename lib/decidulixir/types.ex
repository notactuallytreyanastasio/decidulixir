defmodule Decidulixir.Types do
  @moduledoc """
  Shared Ecto types for the decision graph.

  These are used as virtual enum types across schemas.
  PostgreSQL enum columns are stored as strings with check constraints.
  """

  @type node_type ::
          :goal | :decision | :option | :action | :outcome | :observation | :revisit

  @type node_status ::
          :active | :superseded | :abandoned | :pending | :completed | :rejected

  @type edge_type ::
          :leads_to | :requires | :chosen | :rejected | :blocks | :enables

  @type description_source :: :manual | :ai | :filename

  @node_types ~w(goal decision option action outcome observation revisit)a
  @node_statuses ~w(active superseded abandoned pending completed rejected)a
  @edge_types ~w(leads_to requires chosen rejected blocks enables)a
  @description_sources ~w(manual ai filename)a

  @doc "All valid node types."
  @spec node_types() :: [node_type()]
  def node_types, do: @node_types

  @doc "All valid node statuses."
  @spec node_statuses() :: [node_status()]
  def node_statuses, do: @node_statuses

  @doc "All valid edge types."
  @spec edge_types() :: [edge_type()]
  def edge_types, do: @edge_types

  @doc "All valid description sources."
  @spec description_sources() :: [description_source()]
  def description_sources, do: @description_sources

  @doc "Validates that a value is a valid node type."
  @spec valid_node_type?(atom()) :: boolean()
  def valid_node_type?(type), do: type in @node_types

  @doc "Validates that a value is a valid node status."
  @spec valid_node_status?(atom()) :: boolean()
  def valid_node_status?(status), do: status in @node_statuses

  @doc "Validates that a value is a valid edge type."
  @spec valid_edge_type?(atom()) :: boolean()
  def valid_edge_type?(type), do: type in @edge_types

  @doc "Cast a string to a node type atom, or return error."
  @spec cast_node_type(String.t() | atom()) :: {:ok, node_type()} | :error
  def cast_node_type(type) when is_atom(type) do
    if valid_node_type?(type), do: {:ok, type}, else: :error
  end

  def cast_node_type(type) when is_binary(type) do
    case safe_to_atom(type, @node_types) do
      nil -> :error
      atom -> {:ok, atom}
    end
  end

  @doc "Cast a string to a node status atom, or return error."
  @spec cast_node_status(String.t() | atom()) :: {:ok, node_status()} | :error
  def cast_node_status(status) when is_atom(status) do
    if valid_node_status?(status), do: {:ok, status}, else: :error
  end

  def cast_node_status(status) when is_binary(status) do
    case safe_to_atom(status, @node_statuses) do
      nil -> :error
      atom -> {:ok, atom}
    end
  end

  @doc "Cast a string to an edge type atom, or return error."
  @spec cast_edge_type(String.t() | atom()) :: {:ok, edge_type()} | :error
  def cast_edge_type(type) when is_atom(type) do
    if valid_edge_type?(type), do: {:ok, type}, else: :error
  end

  def cast_edge_type(type) when is_binary(type) do
    case safe_to_atom(type, @edge_types) do
      nil -> :error
      atom -> {:ok, atom}
    end
  end

  defp safe_to_atom(string, valid_atoms) do
    Enum.find(valid_atoms, fn atom -> Atom.to_string(atom) == string end)
  end
end
