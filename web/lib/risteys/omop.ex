defmodule Risteys.OMOP do
  @moduledoc """
  The OMOP context.
  """

  import Ecto.Query, warn: false
  alias Risteys.Repo
  alias Risteys.OMOP.Concept
  alias Risteys.OMOP.LOINCRelationship

  require Logger

  @doc """
  List lab tests and their parent LOINC component.
  """
  def get_lab_tests_tree() do
    Repo.all(
      from rel in LOINCRelationship,
        left_join: lab_test in Concept,
        on: rel.lab_test_id == lab_test.id,
        left_join: loinc_component in Concept,
        on: rel.loinc_component_id == loinc_component.id,
        select: %{
          lab_test_concept_id: lab_test.concept_id,
          lab_test_concept_name: lab_test.concept_name,
          loinc_component_concept_id: loinc_component.concept_id,
          loinc_component_concept_name: loinc_component.concept_name
        }
    )
    |> Enum.reduce(
      %{},
      fn rec, acc ->
        tree_key =
          %{
            loinc_component_concept_id: rec.loinc_component_concept_id,
            loinc_component_concept_name: rec.loinc_component_concept_name
          }

        new_child =
          %{
            lab_test_concept_id: rec.lab_test_concept_id,
            lab_test_concept_name: rec.lab_test_concept_name
          }

        children =
          acc
          |> Map.get(tree_key, MapSet.new())
          |> MapSet.put(new_child)

        Map.put(acc, tree_key, children)
      end
    )
    |> Enum.map(fn {loinc_component, lab_tests} ->
      lab_tests = Enum.sort_by(lab_tests, fn %{lab_test_concept_name: name} -> name end)

      %{
        loinc_component_concept_name: loinc_component.loinc_component_concept_name,
        loinc_component_concept_id: loinc_component.loinc_component_concept_id,
        lab_tests: lab_tests
      }
    end)
    |> Enum.sort_by(fn %{loinc_component_concept_name: name} -> name end)
  end

  @doc """
  Get a map from OMOP Concept IDs to the database IDs of the OMOP concepts.
  """
  def get_map_omop_ids() do
    Repo.all(
      from omop_concept in Concept,
        select: {omop_concept.concept_id, omop_concept.id}
    )
    |> Enum.into(%{})
  end

  @doc """
  Reset the OMOP concepts and LOINC relationships from files.
  """
  def import_lab_test_loinc_concepts(
        omop_ids_file_path,
        loinc_concepts_file_path,
        loinc_relationships_file_path
      ) do
    concept_id_pairs =
      find_loinc_relationship_pairs(omop_ids_file_path, loinc_relationships_file_path)

    reset_from_loinc_relationships(concept_id_pairs, loinc_concepts_file_path)
  end

  # Find pairs of concept IDs from the LOINC relationships file where the lab
  # test concept ID is in the provided list of OMOP concept IDs.
  defp find_loinc_relationship_pairs(omop_ids_file_path, loinc_relationships_file_path) do
    Logger.debug("Finding list of {lab test, LOINC component} pairs from concept IDs: Start.")

    Logger.debug("Parsing subset of OMOP concept IDs from file.")

    subset_concept_ids =
      omop_ids_file_path
      |> File.stream!(line_or_bytes: :line)
      |> Stream.map(&Jason.decode!/1)
      |> Stream.map(fn %{"OMOP_CONCEPT_ID" => omop_id} -> omop_id end)
      |> Stream.reject(fn omop_id -> omop_id == "NA" end)
      |> Enum.into(MapSet.new())

    Logger.debug(
      "Parsing LOINC relationships file to find list of {lab test, LOINC component} pairs."
    )

    relationship_concept_ids =
      loinc_relationships_file_path
      |> File.stream!()
      |> CSV.decode!(headers: true)
      |> Stream.filter(fn %{"concept_id_1" => concept_id, "relationship_id" => relationship} ->
        MapSet.member?(subset_concept_ids, concept_id) and relationship == "Has component"
      end)
      |> Enum.map(fn %{
                       "concept_id_1" => lab_test_concept_id,
                       "concept_id_2" => loinc_component_concept_id
                     } ->
        {lab_test_concept_id, loinc_component_concept_id}
      end)

    Logger.debug("Finding list of {lab test, LOINC component} pairs from concept IDs: End.")

    relationship_concept_ids
  end

  # Import a lab test OMOP concepts and LOINC components files.
  #
  # This will reset all the OMOP concepts currently in the database by the one
  # provided in the call to this function.
  defp reset_from_loinc_relationships(concept_id_pairs, loinc_concepts_file_path) do
    # 1. Get the concept names for all the lab test and component concepts
    concept_ids_set =
      concept_id_pairs
      |> Enum.reduce(
        MapSet.new(),
        fn {lab_test_concept_id, loinc_component_concept_id}, acc ->
          acc
          |> MapSet.put(lab_test_concept_id)
          |> MapSet.put(loinc_component_concept_id)
        end
      )

    concept_names_map =
      loinc_concepts_file_path
      |> File.stream!()
      |> CSV.decode!(headers: true)
      |> Stream.filter(fn %{"concept_id" => concept_id} ->
        MapSet.member?(concept_ids_set, concept_id)
      end)
      |> Stream.map(fn %{"concept_id" => concept_id, "concept_name" => concept_name} ->
        {concept_id, concept_name}
      end)
      |> Enum.into(%{})

    pairs_with_names =
      for {lab_test_concept_id, loinc_component_concept_id} <- concept_id_pairs do
        lab_test_concept_name = Map.fetch!(concept_names_map, lab_test_concept_id)
        loinc_component_concept_name = Map.fetch!(concept_names_map, loinc_component_concept_id)

        {
          %{concept_id: lab_test_concept_id, concept_name: lab_test_concept_name},
          %{concept_id: loinc_component_concept_id, concept_name: loinc_component_concept_name}
        }
      end

    # 2. Update the database
    Logger.debug("Resetting all OMOP concepts and LOINC relationships in the database: Start.")

    Repo.transaction(fn ->
      Risteys.Repo.delete_all(LOINCRelationship)
      Risteys.Repo.delete_all(Concept)

      Enum.each(pairs_with_names, fn {lab_test, loinc_component} ->
        create_concept_pair(lab_test, loinc_component)
      end)
    end)

    Logger.debug("Resetting all OMOP concepts and LOINC relationships in the database: End.")
  end

  defp create_concept_pair(lab_test, loinc_component) do
    Repo.transaction(fn ->
      # 1. Get or insert concepts
      lab_test_struct = get_or_insert_concept(lab_test)
      loinc_component_struct = get_or_insert_concept(loinc_component)

      # 2. Insert lab test / LOINC component relationship
      %LOINCRelationship{}
      |> LOINCRelationship.changeset(%{
        lab_test_id: lab_test_struct.id,
        loinc_component_id: loinc_component_struct.id
      })
      |> Repo.insert!()
    end)
  end

  defp get_or_insert_concept(attrs) do
    case Repo.get_by(Concept, concept_id: attrs.concept_id) do
      nil -> create_concept(attrs)
      existing -> existing
    end
  end

  defp create_concept(attrs) do
    %Concept{}
    |> Concept.changeset(attrs)
    |> Repo.insert!()
  end

  def get_parent_component(lab_test_concept_id) do
    Repo.one(
      from lab_test in Concept,
        join: rel in LOINCRelationship,
        on: rel.lab_test_id == lab_test.id,
        join: loinc_component in Concept,
        on: rel.loinc_component_id == loinc_component.id,
        where: lab_test.concept_id == ^lab_test_concept_id,
        select: loinc_component
    )
  end

  def list_children_lab_tests(loinc_component) do
    Repo.all(
      from lab_test in Concept,
        join: rel in LOINCRelationship,
        on: lab_test.id == rel.lab_test_id,
        where: rel.loinc_component_id == ^loinc_component.id,
        select: lab_test
    )
  end
end
