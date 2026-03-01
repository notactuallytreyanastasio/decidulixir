defmodule Decidulixir.GitHub.IssueCache do
  @moduledoc """
  Local cache for GitHub issue data, used by the web viewer.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          issue_number: integer(),
          repo: String.t(),
          title: String.t(),
          body: String.t() | nil,
          state: String.t(),
          html_url: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          cached_at: DateTime.t()
        }

  schema "github_issue_cache" do
    field :issue_number, :integer
    field :repo, :string
    field :title, :string
    field :body, :string
    field :state, :string
    field :html_url, :string
    field :created_at, :utc_datetime
    field :updated_at, :utc_datetime
    field :cached_at, :utc_datetime
  end

  @required_fields ~w(issue_number repo title state html_url)a
  @optional_fields ~w(body created_at updated_at cached_at)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(issue, attrs) do
    issue
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:state, ~w(open closed))
    |> unique_constraint([:issue_number, :repo])
    |> maybe_set_cached_at()
  end

  defp maybe_set_cached_at(changeset) do
    case get_field(changeset, :cached_at) do
      nil -> put_change(changeset, :cached_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
