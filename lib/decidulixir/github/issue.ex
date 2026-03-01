defmodule Decidulixir.Github.Issue do
  @moduledoc """
  Cached GitHub issue data for linking to decision graph nodes.

  Stores issue metadata fetched via the `gh` CLI so it can be
  displayed in the graph viewer without repeated API calls.
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
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          cached_at: DateTime.t()
        }

  schema "github_issues" do
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

  @required ~w(issue_number repo title state html_url cached_at)a
  @optional ~w(body created_at updated_at)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(issue, attrs) do
    issue
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint([:issue_number, :repo])
  end
end
