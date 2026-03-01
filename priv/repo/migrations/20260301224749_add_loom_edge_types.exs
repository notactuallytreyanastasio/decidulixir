defmodule Decidulixir.Repo.Migrations.AddLoomEdgeTypes do
  use Ecto.Migration

  @moduledoc """
  Adds support for Loom adapter edge types: :supersedes and :supports.

  Since edge_type is stored as a string column (not a DB enum), no schema
  change is needed. The new values are validated by Ecto.Enum in the
  GraphEdge schema. This migration exists as documentation and to keep
  the migration timeline consistent.
  """

  def change do
    # Edge types are stored as strings, validated by Ecto.Enum.
    # Adding :supersedes and :supports requires only schema changes.
    # This migration is intentionally empty — it marks the point
    # where Loom edge type support was added.
  end
end
