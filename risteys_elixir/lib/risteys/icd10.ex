defmodule Risteys.Icd10 do
  use Ecto.Schema
  import Ecto.Changeset

  schema "icd10s" do
    field :code, :string
    field :description, :string

    many_to_many :phenocodes, Risteys.Phenocode, join_through: Risteys.PhenocodeIcd10

    timestamps()
  end

  @doc false
  def changeset(icd10, attrs) do
    icd10
    |> cast(attrs, [:code, :description])
    |> validate_required([:code, :description])
    |> unique_constraint(:code)
  end

  # Get info on ICD-10 from the source file and transform it into
  # appropriate data structures.
  # Dotted ICD-10s as input, undotted ICD-10s as output.
  def init_parser(file_path) do # called from import_endpoint_csv.exs with icd10fi_file_path as an argument
    map_undotted_dotted = # a map, where keys are undotted ICD-10s and values are dotted ICD-10s
      file_path
      |> File.stream!()
      |> CSV.decode!(headers: true)
      |> Enum.reduce(%{}, fn %{"CodeId" => dotted}, acc ->
        undotted = String.replace(dotted, ".", "")
        Map.put(acc, undotted, dotted)
      end)

    # saves to icd10s variable all keys from map_undotted_dotted, i.e. undotted ICD-10s
    icd10s = Map.keys(map_undotted_dotted)

    # map, key "child" is value of "CodeId" column and value "parent" is value of "ParentId" column, from which dots are removed
    map_child_parent =
      file_path
      |> File.stream!()
      |> CSV.decode!(headers: true)
      |> Enum.reduce(%{}, fn %{"CodeId" => child, "ParentId" => parent}, acc ->
        child = String.replace(child, ".", "")
        parent = String.replace(parent, ".", "")
        Map.put(acc, child, parent)
      end)

    # ????? a map, key "parent" is the value of "ParentId" column and value is a MapSet data structure of values in "CodeId" column????
    map_parent_children =
      Enum.reduce(map_child_parent, %{}, fn {child, parent}, acc ->
        Map.update(acc, parent, MapSet.new([child]), fn set ->
          MapSet.put(set, child) # adds child to set if not already there
        end)
      end)

    {icd10s, map_undotted_dotted, map_child_parent, map_parent_children}
  end

  # Transform an undotted ICD-10 FI to its dotted representation.
  # Note that an ICD-10 FI can be a "ICD range", like "W00-W19".
  def to_dotted(icd10, map) do
    Map.fetch!(map, icd10)
  end

  # Takes a raw ICD-10 rule and apply the logic to get a set of ICD-10s.
  # Work is done with undotted ICD-10 codes, both input and output.
  def parse_rule(nil, _, _, _), do: MapSet.new()
  def parse_rule("", _, _, _), do: MapSet.new()

  def parse_rule(pattern, icd10s, map_child_parent, map_parent_children) do
    # ICD rules starting with % are mode encoding.
    pattern =
      case String.at(pattern, 0) do
	"%" -> String.trim_leading(pattern, "%")
	_ -> pattern
      end

    if Map.has_key?(map_child_parent, pattern) do
      # Return early if it's an exact match
      MapSet.new([pattern])
    else
      # Find the minimum set of ICD-10 (with using ICD-10 categories) that meet the definition

      # In endpoint definition, symptoms pair are coded with "&" to
      # denote either "+" or "*" to are used in the real symptoms pairs.
      symbols_symptom_pair = "[\\*\\+]"
      pattern = String.replace(pattern, "&", symbols_symptom_pair)

      # Match only ICDs that starts with the pattern.
      # For example this prevents "N77.0*A60.0" matching on "A6[0-4]"
      regex = Regex.compile!("^(#{pattern})")

      # 1. Get all matches of the regex on the ICD-10s
      icd10s
      # Exclude range ICDs from matching
      |> Enum.reject(fn icd -> String.contains?(icd, "-") end)
      |> Enum.filter(fn code -> Regex.match?(regex, code) end)
      |> MapSet.new()
      # 2. Group them by parent and bubble up until no reduction possible
      |> group_reduce(map_child_parent, map_parent_children)
    end
  end

  # Actual algorithm to expand an ICD-10 rule into a set of matching ICD-10s.
  defp group_reduce(matches, map_child_parent, map_parent_children) do
    {add, remove} =
      matches
      # Group matches by common parent
      |> Enum.reduce(%{}, fn match, acc ->
        %{^match => parent} = map_child_parent

        Map.update(
          acc,
          parent,
          MapSet.new([match]),
          fn set -> MapSet.put(set, match) end
        )
      end)
      # Replace a bunch of codes by their parent if they fully define the parent
      |> Enum.reduce({MapSet.new(), MapSet.new()}, fn {parent, children}, {add, remove} ->
        %{^parent => all_children} = map_parent_children

        if MapSet.equal?(children, all_children) do
          # A bunch of children codes can be reduce to their parent
          add = MapSet.put(add, parent)
          remove = MapSet.union(remove, children)
          {add, remove}
        else
          # Can't reduce the group since it doesn't fully represent the parent
          add = MapSet.union(add, children)
          {add, remove}
        end
      end)

    reduced = MapSet.difference(add, remove)

    # recurs
    if MapSet.equal?(matches, reduced) do
      reduced
    else
      group_reduce(reduced, map_child_parent, map_parent_children)
    end
  end
end
