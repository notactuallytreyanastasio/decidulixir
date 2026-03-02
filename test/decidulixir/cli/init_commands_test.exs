defmodule Decidulixir.CLI.InitCommandsTest do
  use ExUnit.Case, async: true

  alias Decidulixir.CLI.Commands.{CheckUpdate, Init, Update}

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

    test "parses all short aliases" do
      assert Init.parse(["-o"]).opts[:opencode] == true
      assert Init.parse(["-w"]).opts[:windsurf] == true
    end

    test "parses empty args to empty config" do
      parsed = Init.parse([])
      assert parsed.opts == []
      assert parsed.args == []
    end

    test "ignores invalid flags" do
      parsed = Init.parse(["--invalid", "--claude"])
      assert parsed.opts[:claude] == true
    end

    test "parses combined flags" do
      parsed = Init.parse(["--claude", "--opencode", "--windsurf"])
      assert parsed.opts[:claude] == true
      assert parsed.opts[:opencode] == true
      assert parsed.opts[:windsurf] == true
    end
  end

  describe "Update command" do
    test "has correct name and description" do
      assert Update.name() == "update"
      assert Update.description() =~ "Update"
    end

    test "parse returns empty map" do
      assert Update.parse(["--any"]) == %{}
    end
  end

  describe "CheckUpdate command" do
    test "has correct name and description" do
      assert CheckUpdate.name() == "check-update"
      assert CheckUpdate.description() =~ "update"
    end

    test "parse returns empty map" do
      assert CheckUpdate.parse([]) == %{}
    end
  end
end
