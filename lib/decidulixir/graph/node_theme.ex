defmodule Decidulixir.Graph.NodeTheme do
  @moduledoc """
  Join table linking nodes to themes with source tracking.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Decidulixir.Graph.{Node, Theme}

  @type t :: %__MODULE__{
          node_id: integer(),
          theme_id: integer(),
          source: String.t(),
          inserted_at: DateTime.t() | nil
        }

  @primary_key false
  schema "node_themes" do
    belongs_to :node, Node
    belongs_to :theme, Theme
    field :source, :string, default: "manual"

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(node_theme, attrs) do
    node_theme
    |> cast(attrs, ~w(node_id theme_id source)a)
    |> validate_required(~w(node_id theme_id)a)
    |> validate_inclusion(:source, ~w(manual suggested ai))
    |> foreign_key_constraint(:node_id)
    |> foreign_key_constraint(:theme_id)
    |> unique_constraint([:node_id, :theme_id])
  end
end
