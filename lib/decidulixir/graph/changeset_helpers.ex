defmodule Decidulixir.Graph.ChangesetHelpers do
  @moduledoc """
  Shared changeset helpers for decision graph schemas.

  Extracts common patterns like UUID generation and timestamp defaults
  so they aren't duplicated across every schema module.
  """

  import Ecto.Changeset

  @doc "Generates a UUID for :change_id if not already set."
  @spec maybe_generate_change_id(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def maybe_generate_change_id(changeset) do
    case get_field(changeset, :change_id) do
      nil -> put_change(changeset, :change_id, Ecto.UUID.generate())
      _ -> changeset
    end
  end

  @doc "Sets a datetime field to now if not already set."
  @spec maybe_set_timestamp(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def maybe_set_timestamp(changeset, field) do
    case get_field(changeset, field) do
      nil -> put_change(changeset, field, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
