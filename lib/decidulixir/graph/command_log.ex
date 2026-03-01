defmodule Decidulixir.Graph.CommandLog do
  @moduledoc """
  Log of CLI commands executed against the decision graph.

  Tracks what commands were run, their output, and optionally
  which decision node they relate to.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Decidulixir.Graph.Node

  @type t :: %__MODULE__{
          id: integer() | nil,
          command: String.t(),
          description: String.t() | nil,
          working_dir: String.t() | nil,
          exit_code: integer() | nil,
          stdout: String.t() | nil,
          stderr: String.t() | nil,
          started_at: DateTime.t(),
          completed_at: DateTime.t() | nil,
          duration_ms: integer() | nil,
          node_id: integer() | nil
        }

  schema "graph_commands" do
    field :command, :string
    field :description, :string
    field :working_dir, :string
    field :exit_code, :integer
    field :stdout, :string
    field :stderr, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :duration_ms, :integer
    belongs_to :node, Node, foreign_key: :node_id
  end

  @required ~w(command started_at)a
  @optional ~w(description working_dir exit_code stdout stderr completed_at duration_ms node_id)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(log, attrs) do
    log
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:node_id)
  end
end
