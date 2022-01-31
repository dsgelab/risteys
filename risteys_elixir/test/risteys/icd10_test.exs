defmodule Risteys.Icd10v2Test do
  use ExUnit.Case, async: true

  alias Risteys.Icd10

  setup_all do
    icd10_test_path = "test/data/test_icd10.csv"

    {
      icd10s,
      map_undotted_dotted,
      map_child_parent,
      map_parent_children
    } = Icd10.init_parser(icd10_test_path)

    [
      icd10s: icd10s,
      map_undotted_dotted: map_undotted_dotted,
      map_child_parent: map_child_parent,
      map_parent_children: map_parent_children
    ]
  end

  defp assert_parsed(cell, expected, context) do
    parsed =
      cell
      |> Icd10.parse_rule(context.icd10s, context.map_child_parent, context.map_parent_children)
      |> Enum.map(&Icd10.to_dotted(&1, context.map_undotted_dotted))

    assert MapSet.equal?(MapSet.new(parsed), MapSet.new(expected))
  end

  describe "Basic matches" do
    test "Simple single match", context do
      cell = "A040"
      expected = ["A04.0"]
      assert_parsed(cell, expected, context)
    end

    test "Simple multi-match", context do
      cell = "A04[8-9]"
      expected = ["A04.8", "A04.9"]
      assert_parsed(cell, expected, context)
    end
  end

  describe "Symptom-cause pairs" do
    test "symptom*cause", context do
      cell = "T58&F0289"
      expected = ["T58+F02.89"]
      assert_parsed(cell, expected, context)
    end

    test "cause+symptom", context do
      cell = "G590&E104"
      expected = ["G59.0*E10.4"]
      assert_parsed(cell, expected, context)
    end
  end

  describe "Regex with dot" do
    test "C34.[13]", context do
      # The '.' must be interpreted as a regex pattern matching a single character
      cell = "C34.[13]"
      expected = ["C34.01&", "C34.03&", "C34.11&", "C34.13&"]
      assert_parsed(cell, expected, context)
    end
  end

  describe "Mode definition" do
    test "%J45|J46", context do
      cell = "%J45|J46"
      expected = ["J45", "J46"]
      assert_parsed(cell, expected, context)
    end
  end

  describe "Group matching" do
    test "Single expansion", context do
      cell = "XXX[1-2]"
      expected = ["XXX1-XXX2"]
      assert_parsed(cell, expected, context)
    end

    test "Multi expansion", context do
      cell = "XXX[1-2][1-2]"
      expected = ["XXX1-XXX2"]
      assert_parsed(cell, expected, context)
    end
  end
end
