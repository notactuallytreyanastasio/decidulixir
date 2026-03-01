defmodule Decidulixir.Graph.MetadataTest do
  use ExUnit.Case, async: true

  alias Decidulixir.Graph.Metadata

  describe "build/1" do
    test "builds metadata from keyword list" do
      result = Metadata.build(confidence: 85, branch: "main", commit: "abc123")
      assert result == %{"confidence" => 85, "branch" => "main", "commit" => "abc123"}
    end

    test "handles prompt" do
      result = Metadata.build(prompt: "do the thing")
      assert result == %{"prompt" => "do the thing"}
    end

    test "handles files" do
      result = Metadata.build(files: "a.ex,b.ex")
      assert result == %{"files" => "a.ex,b.ex"}
    end

    test "handles agent_name" do
      result = Metadata.build(agent_name: "explorer")
      assert result == %{"agent_name" => "explorer"}
    end

    test "handles arbitrary keys" do
      result = Metadata.build(custom: "value")
      assert result == %{"custom" => "value"}
    end

    test "returns empty map for empty list" do
      assert Metadata.build([]) == %{}
    end
  end

  describe "merge/2" do
    test "merges two maps" do
      assert Metadata.merge(%{"a" => 1}, %{"b" => 2}) == %{"a" => 1, "b" => 2}
    end

    test "new values override existing" do
      assert Metadata.merge(%{"a" => 1}, %{"a" => 2}) == %{"a" => 2}
    end

    test "handles nil" do
      assert Metadata.merge(nil, %{"a" => 1}) == %{"a" => 1}
      assert Metadata.merge(%{"a" => 1}, nil) == %{"a" => 1}
    end
  end

  describe "getters" do
    test "get_confidence/1" do
      assert Metadata.get_confidence(%{"confidence" => 85}) == 85
      assert Metadata.get_confidence(%{}) == nil
      assert Metadata.get_confidence(nil) == nil
    end

    test "get_prompt/1" do
      assert Metadata.get_prompt(%{"prompt" => "hello"}) == "hello"
      assert Metadata.get_prompt(nil) == nil
    end

    test "get_branch/1" do
      assert Metadata.get_branch(%{"branch" => "main"}) == "main"
      assert Metadata.get_branch(nil) == nil
    end

    test "get_commit/1" do
      assert Metadata.get_commit(%{"commit" => "abc"}) == "abc"
      assert Metadata.get_commit(nil) == nil
    end

    test "get_files/1" do
      assert Metadata.get_files(%{"files" => "a.ex,b.ex"}) == ["a.ex", "b.ex"]
      assert Metadata.get_files(%{"files" => ["a.ex"]}) == ["a.ex"]
      assert Metadata.get_files(%{}) == []
      assert Metadata.get_files(nil) == []
    end
  end

  describe "setters" do
    test "set_confidence/2" do
      result = Metadata.set_confidence(%{"branch" => "main"}, 90)
      assert result == %{"branch" => "main", "confidence" => 90}
    end

    test "set_branch/2" do
      result = Metadata.set_branch(%{}, "feature-x")
      assert result == %{"branch" => "feature-x"}
    end

    test "set_commit/2" do
      result = Metadata.set_commit(nil, "abc123")
      assert result == %{"commit" => "abc123"}
    end

    test "set_prompt/2" do
      result = Metadata.set_prompt(%{"confidence" => 80}, "do this")
      assert result == %{"confidence" => 80, "prompt" => "do this"}
    end
  end
end
