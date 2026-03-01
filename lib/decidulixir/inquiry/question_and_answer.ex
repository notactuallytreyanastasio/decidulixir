defmodule Decidulixir.Inquiry.QuestionAndAnswer do
  @moduledoc """
  A Q&A interaction recorded during decision-making.

  Captures user prompts, the full prompt context sent to the LLM,
  and the response received, for later review and audit.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_prompt: String.t(),
          total_prompt: String.t(),
          response: String.t(),
          context: map() | nil,
          inserted_at: DateTime.t(),
          deleted_at: DateTime.t() | nil
        }

  schema "questions_and_answers" do
    field :user_prompt, :string
    field :total_prompt, :string
    field :response, :string
    field :context, :map
    field :inserted_at, :utc_datetime
    field :deleted_at, :utc_datetime
  end

  @required ~w(user_prompt total_prompt response inserted_at)a
  @optional ~w(context deleted_at)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(qa, attrs) do
    qa
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end
end
