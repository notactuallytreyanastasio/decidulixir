defmodule Decidulixir.CLI.FormatterTest do
  use ExUnit.Case, async: true

  alias Decidulixir.CLI.Formatter

  describe "format_node/1" do
    test "formats node with basic fields" do
      node = %{id: 1, node_type: :goal, status: :active, title: "Test Goal", metadata: nil}
      result = Formatter.format_node(node)
      assert result =~ "1"
      assert result =~ "goal"
      assert result =~ "active"
      assert result =~ "Test Goal"
    end

    test "includes confidence when present" do
      node = %{
        id: 42,
        node_type: :action,
        status: :pending,
        title: "Do stuff",
        metadata: %{"confidence" => 85}
      }

      result = Formatter.format_node(node)
      assert result =~ "[85%]"
    end
  end

  describe "format_edge/1" do
    test "formats edge with rationale" do
      edge = %{id: 1, from_node_id: 2, to_node_id: 3, edge_type: :leads_to, rationale: "reason"}
      result = Formatter.format_edge(edge)
      assert result =~ "2"
      assert result =~ "3"
      assert result =~ "leads_to"
      assert result =~ "reason"
    end

    test "formats edge without rationale" do
      edge = %{id: 1, from_node_id: 2, to_node_id: 3, edge_type: :leads_to, rationale: nil}
      result = Formatter.format_edge(edge)
      assert result =~ "2"
      assert result =~ "3"
      refute result =~ "nil"
    end
  end

  describe "format_changeset_errors/1" do
    test "formats changeset errors" do
      changeset =
        {%{}, %{title: :string}}
        |> Ecto.Changeset.cast(%{}, [:title])
        |> Ecto.Changeset.validate_required([:title])

      result = Formatter.format_changeset_errors(changeset)
      assert result =~ "title"
      assert result =~ "can't be blank"
    end
  end

  describe "json/1" do
    test "returns pretty-printed JSON string" do
      result = Formatter.json(%{a: 1})
      assert is_binary(result)
      assert Jason.decode!(result) == %{"a" => 1}
    end
  end
end
