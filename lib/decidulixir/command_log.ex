defmodule Decidulixir.CommandLog do
  @moduledoc """
  Ecto schema for CLI command history tracking.

  Records every decidulixir CLI invocation with timing, exit code,
  and optional association to a decision node.
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
          decision_node_id: integer() | nil
        }

  schema "command_log" do
    field :command, :string
    field :description, :string
    field :working_dir, :string
    field :exit_code, :integer
    field :stdout, :string
    field :stderr, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :duration_ms, :integer
    belongs_to :decision_node, Node, foreign_key: :decision_node_id
  end

  @required_fields ~w(command)a
  @optional_fields ~w(description working_dir exit_code stdout stderr started_at completed_at duration_ms decision_node_id)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(log, attrs) do
    log
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:decision_node_id)
    |> maybe_set_started_at()
  end

  defp maybe_set_started_at(changeset) do
    case get_field(changeset, :started_at) do
      nil -> put_change(changeset, :started_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
