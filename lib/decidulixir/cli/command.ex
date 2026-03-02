defmodule Decidulixir.CLI.Command do
  @moduledoc """
  Behaviour for CLI command modules.

  Each command parses argv into a config hash and pattern-matches
  on that hash in execute/1 function heads.
  """

  @type config :: map()
  @type updates :: %{optional(:active_goal) => integer()}
  @type result :: :ok | {:ok, updates()} | {:error, String.t()}

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback parse(argv :: [String.t()]) :: config()
  @callback execute(config()) :: result()
end
