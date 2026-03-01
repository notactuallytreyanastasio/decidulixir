defmodule Decidulixir.TypesTest do
  use ExUnit.Case, async: true

  alias Decidulixir.Types

  describe "node_types/0" do
    test "returns all 7 node types" do
      types = Types.node_types()
      assert length(types) == 7
      assert :goal in types
      assert :decision in types
      assert :option in types
      assert :action in types
      assert :outcome in types
      assert :observation in types
      assert :revisit in types
    end
  end

  describe "cast_node_type/1" do
    test "casts valid string to atom" do
      assert {:ok, :goal} = Types.cast_node_type("goal")
      assert {:ok, :revisit} = Types.cast_node_type("revisit")
    end

    test "casts valid atom through" do
      assert {:ok, :action} = Types.cast_node_type(:action)
    end

    test "rejects invalid types" do
      assert :error = Types.cast_node_type("invalid")
      assert :error = Types.cast_node_type(:bogus)
    end
  end

  describe "cast_node_status/1" do
    test "casts valid statuses" do
      assert {:ok, :active} = Types.cast_node_status("active")
      assert {:ok, :superseded} = Types.cast_node_status(:superseded)
    end

    test "rejects invalid statuses" do
      assert :error = Types.cast_node_status("nope")
    end
  end

  describe "cast_edge_type/1" do
    test "casts valid edge types" do
      assert {:ok, :leads_to} = Types.cast_edge_type("leads_to")
      assert {:ok, :chosen} = Types.cast_edge_type(:chosen)
      assert {:ok, :rejected} = Types.cast_edge_type("rejected")
    end

    test "rejects invalid edge types" do
      assert :error = Types.cast_edge_type("connected")
    end
  end
end
