defmodule Decidulixir.Repo do
  use Ecto.Repo,
    otp_app: :decidulixir,
    adapter: Ecto.Adapters.Postgres
end
