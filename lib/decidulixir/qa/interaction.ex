defmodule Decidulixir.QA.Interaction do
  @moduledoc """
  Ecto schema for Q&A interactions (user questions and AI responses).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_prompt: String.t(),
          total_prompt: String.t(),
          response: String.t(),
          context_json: map() | nil,
          inserted_at: DateTime.t() | nil,
          deleted_at: DateTime.t() | nil
        }

  schema "qa_interactions" do
    field :user_prompt, :string
    field :total_prompt, :string
    field :response, :string
    field :context_json, :map
    field :inserted_at, :utc_datetime
    field :deleted_at, :utc_datetime
  end

  @required_fields ~w(user_prompt total_prompt response)a
  @optional_fields ~w(context_json inserted_at deleted_at)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> maybe_set_inserted_at()
  end

  defp maybe_set_inserted_at(changeset) do
    case get_field(changeset, :inserted_at) do
      nil -> put_change(changeset, :inserted_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
