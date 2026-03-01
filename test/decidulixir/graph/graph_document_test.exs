defmodule Decidulixir.Graph.GraphDocumentTest do
  use Decidulixir.DataCase, async: true

  alias Decidulixir.Graph.{Node, GraphDocument}
  alias Decidulixir.Repo

  defp create_node! do
    %Node{}
    |> Node.changeset(%{node_type: :goal, title: "Test node"})
    |> Repo.insert!()
  end

  defp valid_doc_attrs(node) do
    %{
      node_id: node.id,
      node_change_id: node.change_id,
      content_hash: "sha256:abc123",
      original_filename: "spec.pdf",
      storage_filename: "sha256_abc123.pdf",
      mime_type: "application/pdf",
      file_size: 1024
    }
  end

  describe "changeset/2" do
    test "valid with required fields" do
      node = create_node!()
      changeset = GraphDocument.changeset(%GraphDocument{}, valid_doc_attrs(node))
      assert changeset.valid?
    end

    test "generates change_id" do
      node = create_node!()
      changeset = GraphDocument.changeset(%GraphDocument{}, valid_doc_attrs(node))
      assert Ecto.Changeset.get_field(changeset, :change_id) != nil
    end

    test "sets attached_at automatically" do
      node = create_node!()
      changeset = GraphDocument.changeset(%GraphDocument{}, valid_doc_attrs(node))
      assert Ecto.Changeset.get_field(changeset, :attached_at) != nil
    end

    test "defaults storage_backend to local" do
      node = create_node!()
      changeset = GraphDocument.changeset(%GraphDocument{}, valid_doc_attrs(node))
      assert Ecto.Changeset.get_field(changeset, :storage_backend) == "local"
    end

    test "accepts s3 storage_backend" do
      node = create_node!()
      attrs = Map.put(valid_doc_attrs(node), :storage_backend, "s3")
      changeset = GraphDocument.changeset(%GraphDocument{}, attrs)
      assert changeset.valid?
    end

    test "rejects invalid storage_backend" do
      node = create_node!()
      attrs = Map.put(valid_doc_attrs(node), :storage_backend, "gcs")
      changeset = GraphDocument.changeset(%GraphDocument{}, attrs)
      refute changeset.valid?
      assert errors_on(changeset)[:storage_backend]
    end

    test "validates description_source inclusion" do
      node = create_node!()
      attrs = Map.put(valid_doc_attrs(node), :description_source, "invalid")
      changeset = GraphDocument.changeset(%GraphDocument{}, attrs)
      refute changeset.valid?
      assert errors_on(changeset)[:description_source]
    end

    test "validates file_size non-negative" do
      node = create_node!()
      attrs = Map.put(valid_doc_attrs(node), :file_size, -1)
      changeset = GraphDocument.changeset(%GraphDocument{}, attrs)
      refute changeset.valid?
      assert errors_on(changeset)[:file_size]
    end

    test "invalid without required fields" do
      changeset = GraphDocument.changeset(%GraphDocument{}, %{})
      refute changeset.valid?
      assert errors_on(changeset)[:node_id]
      assert errors_on(changeset)[:content_hash]
      assert errors_on(changeset)[:original_filename]
    end
  end

  describe "CRUD operations" do
    test "insert and retrieve a document" do
      node = create_node!()

      {:ok, doc} =
        %GraphDocument{}
        |> GraphDocument.changeset(valid_doc_attrs(node))
        |> Repo.insert()

      assert doc.id != nil
      assert doc.change_id != nil
      assert doc.storage_backend == "local"

      fetched = Repo.get!(GraphDocument, doc.id)
      assert fetched.original_filename == "spec.pdf"
      assert fetched.content_hash == "sha256:abc123"
    end

    test "cascade deletes documents when node is deleted" do
      node = create_node!()

      {:ok, doc} =
        %GraphDocument{}
        |> GraphDocument.changeset(valid_doc_attrs(node))
        |> Repo.insert()

      Repo.delete!(node)
      assert Repo.get(GraphDocument, doc.id) == nil
    end
  end
end
