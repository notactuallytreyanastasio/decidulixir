defmodule Decidulixir.CLI.InitCommandsTest do
  use ExUnit.Case, async: true

  alias Decidulixir.CLI.Commands.{Init, Update, CheckUpdate}

  @moduletag :tmp_dir

  describe "Init command" do
    test "has correct name and description" do
      assert Init.name() == "init"
      assert Init.description() =~ "init"
    end

    test "parses backend flags" do
      parsed = Init.parse(["--claude"])
      assert parsed.opts[:claude] == true

      parsed = Init.parse(["--opencode", "--windsurf"])
      assert parsed.opts[:opencode] == true
      assert parsed.opts[:windsurf] == true
    end

    test "parses short aliases" do
      parsed = Init.parse(["-c"])
      assert parsed.opts[:claude] == true
    end
  end

  describe "Update command" do
    test "has correct name and description" do
      assert Update.name() == "update"
      assert Update.description() =~ "Update"
    end
  end

  describe "CheckUpdate command" do
    test "has correct name and description" do
      assert CheckUpdate.name() == "check-update"
      assert CheckUpdate.description() =~ "updating"
    end
  end
end
