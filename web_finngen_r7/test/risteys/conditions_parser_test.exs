defmodule ConditionsParserTest do
  use ExUnit.Case, async: true
  import Risteys.Phenocode, only: [parse_conditions: 1]

  describe "Simpler rules" do
    test "O15_DELIVERY" do
      cell = "O15_DELIVERY"
      expected = ["O15_DELIVERY"]
      assert parse_conditions(cell) == expected
    end

    test "neg: !CML" do
      cell = "!CML"
      expected = ["not CML"]
      assert parse_conditions(cell) == expected
    end
  end

  describe "Multiple conditions" do
    test "and-chained: !DM_EYE_OPER_FOR_NON_DIAB_EXCLUSION&DIABETES_FG" do
      cell = "!DM_EYE_OPER_FOR_NON_DIAB_EXCLUSION&DIABETES_FG"

      expected = [
        "not DM_EYE_OPER_FOR_NON_DIAB_EXCLUSION",
        "and DIABETES_FG"
      ]

      assert parse_conditions(cell) == expected
    end

    test "or-chained: N14_FEMALEINFERT|RX_INFERTILITY" do
      cell = "N14_FEMALEINFERT|RX_INFERTILITY"

      expected = [
        "N14_FEMALEINFERT",
        "or RX_INFERTILITY"
      ]

      assert parse_conditions(cell) == expected
    end
  end

  describe "Misc." do
    test "number of events: K11_KELAUC&K11_ULCER_NEVT>1" do
      cell = "K11_KELAUC&K11_ULCER_NEVT>1"

      expected = [
        "K11_KELAUC",
        "and K11_ULCER number of events >1"
      ]

      assert parse_conditions(cell) == expected
    end
  end
end
