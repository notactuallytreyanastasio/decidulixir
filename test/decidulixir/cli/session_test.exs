defmodule Decidulixir.CLI.SessionTest do
  use ExUnit.Case, async: false

  alias Decidulixir.CLI.Session

  describe "active_goal/0 and set_active_goal/1" do
    test "starts with nil active goal" do
      # Reset to nil for clean test
      Session.set_active_goal(nil)
      assert Session.active_goal() == nil
    end

    test "stores and retrieves active goal" do
      Session.set_active_goal(42)
      assert Session.active_goal() == 42
    end

    test "overwrites previous active goal" do
      Session.set_active_goal(1)
      Session.set_active_goal(2)
      assert Session.active_goal() == 2
    end
  end
end
