defmodule Decidulixir.CLI.ParsersTest do
  use ExUnit.Case, async: true

  alias Decidulixir.CLI.Parsers

  describe "parse_int/1" do
    test "returns nil for nil" do
      assert Parsers.parse_int(nil) == nil
    end

    test "parses valid integer string" do
      assert Parsers.parse_int("42") == 42
    end

    test "parses zero" do
      assert Parsers.parse_int("0") == 0
    end

    test "parses negative integer" do
      assert Parsers.parse_int("-5") == -5
    end

    test "returns error tuple for non-integer string" do
      assert Parsers.parse_int("abc") == {:error, "abc"}
    end

    test "returns error tuple for partial integer" do
      assert Parsers.parse_int("42abc") == {:error, "42abc"}
    end

    test "returns error tuple for empty string" do
      assert Parsers.parse_int("") == {:error, ""}
    end

    test "returns error tuple for float string" do
      assert Parsers.parse_int("3.14") == {:error, "3.14"}
    end
  end
end
