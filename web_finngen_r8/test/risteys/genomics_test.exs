defmodule Risteys.GenomicsTest do
  use Risteys.DataCase

  alias Risteys.Genomics

  describe "genes" do
    alias Risteys.Genomics.Gene

    @valid_attrs %{chromosome: "some chromosome", ensid: "some ensid", name: "some name", start: 42, stop: 42}
    @update_attrs %{chromosome: "some updated chromosome", ensid: "some updated ensid", name: "some updated name", start: 43, stop: 43}
    @invalid_attrs %{chromosome: nil, ensid: nil, name: nil, start: nil, stop: nil}

    def gene_fixture(attrs \\ %{}) do
      {:ok, gene} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Genomics.create_gene()

      gene
    end

    test "list_genes/0 returns all genes" do
      gene = gene_fixture()
      assert Genomics.list_genes() == [gene]
    end

    test "get_gene!/1 returns the gene with given id" do
      gene = gene_fixture()
      assert Genomics.get_gene!(gene.id) == gene
    end

    test "create_gene/1 with valid data creates a gene" do
      assert {:ok, %Gene{} = gene} = Genomics.create_gene(@valid_attrs)
      assert gene.chromosome == "some chromosome"
      assert gene.ensid == "some ensid"
      assert gene.name == "some name"
      assert gene.start == 42
      assert gene.stop == 42
    end

    test "create_gene/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Genomics.create_gene(@invalid_attrs)
    end

    test "update_gene/2 with valid data updates the gene" do
      gene = gene_fixture()
      assert {:ok, %Gene{} = gene} = Genomics.update_gene(gene, @update_attrs)
      assert gene.chromosome == "some updated chromosome"
      assert gene.ensid == "some updated ensid"
      assert gene.name == "some updated name"
      assert gene.start == 43
      assert gene.stop == 43
    end

    test "update_gene/2 with invalid data returns error changeset" do
      gene = gene_fixture()
      assert {:error, %Ecto.Changeset{}} = Genomics.update_gene(gene, @invalid_attrs)
      assert gene == Genomics.get_gene!(gene.id)
    end

    test "delete_gene/1 deletes the gene" do
      gene = gene_fixture()
      assert {:ok, %Gene{}} = Genomics.delete_gene(gene)
      assert_raise Ecto.NoResultsError, fn -> Genomics.get_gene!(gene.id) end
    end

    test "change_gene/1 returns a gene changeset" do
      gene = gene_fixture()
      assert %Ecto.Changeset{} = Genomics.change_gene(gene)
    end
  end
end
