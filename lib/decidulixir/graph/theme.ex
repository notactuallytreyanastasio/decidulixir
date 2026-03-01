defmodule Decidulixir.Graph.Theme do
  @moduledoc """
  Ecto schema for themes (tagging system for decision nodes).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          change_id: Ecto.UUID.t(),
          name: String.t(),
          color: String.t(),
          description: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "themes" do
    field :change_id, Ecto.UUID
    field :name, :string
    field :color, :string, default: "#6366f1"
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(name)a
  @optional_fields ~w(color description change_id)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(theme, attrs) do
    theme
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:name)
    |> maybe_generate_change_id()
  end

  defp maybe_generate_change_id(changeset) do
    case get_field(changeset, :change_id) do
      nil -> put_change(changeset, :change_id, Ecto.UUID.generate())
      _ -> changeset
    end
  end
end
