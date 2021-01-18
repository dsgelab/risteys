defmodule Risteys.Icd10Test do
  use ExUnit.Case, async: true

  alias Risteys.Icd10

  setup_all do
    icd10fi_file_path = "test/data/ICD10_koodistopalvelu_2015-08_26_utf8.csv"

    {icd10s, map_undotted_dotted, map_child_parent, map_parent_children} =
      Icd10.init_parser(icd10fi_file_path)

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
      |> Icd10.parse_rule(
        context.icd10s,
        context.map_child_parent,
        context.map_parent_children
      )
      |> Enum.map(&Icd10.to_dotted(&1, context.map_undotted_dotted))

    assert MapSet.equal?(MapSet.new(parsed), MapSet.new(expected))
  end

  describe "HD ICD 10" do
    test "VIII_EAR_MASTOID: H[6-9]", context do
      # Matches all of ICD chapter VIII: Diseases of the ear and mastoid process
      # Find highest in hierarchy?
      cell = "H[6-9]"
      expected = ["H60-H95"]

      assert_parsed(cell, expected, context)
    end

    test "ST19_INJURY_POISO_CERTA_OTHER_CONSE_EXTER_CAUSES: S|T", context do
      cell = "S|T"
      expected = ["S00-T98"]

      assert_parsed(cell, expected, context)
    end

    test "ENTEROPATH_E_COLI: A040", context do
      # Somehow the endpoint def don't use the '.' found in the ICD-10
      cell = "A040"
      expected = ["A04.0"]

      assert_parsed(cell, expected, context)
    end

    test "BACT_INTEST_INFECTION_NOS: A04[8-9]", context do
      cell = "A04[8-9]"

      expected = [
        "A04.8",
        "A04.9"
      ]

      assert_parsed(cell, expected, context)
    end

    test "AB1_OTHER_BACTERIAL: A[3-4][0-9]", context do
      cell = "A[3-4][0-9]"
      expected = ["A30-A49"]

      assert_parsed(cell, expected, context)
    end

    test "AB1_SEXUAL_TRANSMISSION: A5[0-9]|A6[0-4]", context do
      # Handle the "|"
      # Match for category seems to be found in ICD10 FINN only
      cell = "A5[0-9]|A6[0-4]"
      expected = ["A50-A64"]

      assert_parsed(cell, expected, context)
    end

    test "P16_MECONIUMI_CAUSED_CYSTIC_FIBROSIS: P75*", context do
      # Here '*' is not part of a regex, but marking the code as a symptom
      cell = "P75*"
      expected = ["P75*"]

      assert_parsed(cell, expected, context)
    end

    test "P16_MECONIUM_ILEUS1: P75*E841", context do
      # Here '*' is still not a regex, but the code is the form <symptom> * <reason>
      cell = "P75*E841"
      expected = ["P75*E84.1"]

      assert_parsed(cell, expected, context)
    end

    test "FALLS: W[0-1]|R296", context do
      cell = "W[0-1]|R296"

      expected = [
        "W00-W19",
        "R29.6"
      ]

      assert_parsed(cell, expected, context)
    end

    test "I9_HYPTENS: I10|I11|I12|I13|I15|I674", context do
      cell = "I10|I11|I12|I13|I15|I674"

      expected = [
        # doesn't contain I14, like the cell
        "I10-I15",
        "I67.4"
      ]

      assert_parsed(cell, expected, context)
    end

    test "C3_LUNG_NONSMALL: C34.[123457]", context do
      # Interpret '.' as being in a regex.
      #
      # This endpoint definition leads to several matches since we
      # want many categories to match and for each of them remove a
      # subset (0,6,9).
      #
      # C34: Malignant neoplasm of bronchus and lung
      #  . : any location in bronchus and lung
      # [123457]:
      #   1: epidermoid carcinoma
      #   2: adenocarcinoma
      #   3: bronchoalveolar carcinoma
      #   4: macrocellular anaplastic carcinoma
      #   5: other non-microcellular carcinoma
      #   7: caarcinoid

      cell = "C34.[123457]"

      expected = [
        "C34.01&",
        "C34.02&",
        "C34.03&",
        "C34.04&",
        "C34.05&",
        "C34.07&",
        "C34.11&",
        "C34.12&",
        "C34.13&",
        "C34.14&",
        "C34.15&",
        "C34.17&",
        "C34.21&",
        "C34.22&",
        "C34.23&",
        "C34.24&",
        "C34.25&",
        "C34.27&",
        "C34.31&",
        "C34.32&",
        "C34.33&",
        "C34.34&",
        "C34.35&",
        "C34.37&",
        "C34.81&",
        "C34.82&",
        "C34.83&",
        "C34.84&",
        "C34.85&",
        "C34.87&",
        "C34.91&",
        "C34.92&",
        "C34.93&",
        "C34.94&",
        "C34.95&",
        "C34.97&"
      ]

      assert_parsed(cell, expected, context)
    end

    test "G6_MENINGBACT: G0[0-1]", context do
      cell = "G0[0-1]"
      expected = ["G00", "G01*"]
      assert_parsed(cell, expected, context)
    end

    test "I_INFECT_PARASIT: A|B", context do
      cell = "A|B"
      expected = ["A00-B99"]
      assert_parsed(cell, expected, context)
    end

    test "VI_NERVOUS: G", context do
      cell = "G"
      expected = ["G00-G99"]
      assert_parsed(cell, expected, context)
    end

    test "XIII_MUSCULOSKELET: M", context do
      cell = "M"
      expected = ["M00-M99"]
      assert_parsed(cell, expected, context)
    end

    test "Symptom pairs & ➝ +: T58&F0289", context do
      # From ST19_DEMEN_RELATED_TOXIC_EFFECT_CARBON_MONOX
      # Interpret "&" as a symptom pair, so either "+" or "*".
      cell = "T58&F0289"
      expected = ["T58+F02.89"]
      assert_parsed(cell, expected, context)
    end

    test "Symptom pairs & ➝ *: G590&E104|G590&E114", context do
      # From DM_MONONEURO
      cell = "G590&E104|G590&E114"
      expected = ["G59.0*E10.4", "G59.0*E11.4"]
      assert_parsed(cell, expected, context)
    end

    test "Symptom pairs & ➝ * :  M07&L405|M07[1-3]", context do
      # From M13_PSORIARTH_ICD10
      cell = "M07[0-3]&L405|M07[1-3]"
      expected = [
	"M07.0*L40.5",
	"M07.1*L40.5",
	"M07.2*L40.5",
	"M07.3*L40.5",
	"M07.1*",
	"M07.2*",
	"M07.3*"
      ]
      assert_parsed(cell, expected, context)
    end

    test "Symptom pairs non-matching: F009&G309", context do
      # From AD_U
      #
      # This is a tricky case. The pair F00.9, G30.9 is not found in
      # the official Finnish ICD-10 document, but the pair appears
      # however in the FinnGen data.
      # Best course of action is to not match anything on this pair so
      # it is displayed as is in Risteys.
      cell = "F009&G309"
      expected = []
      assert_parsed(cell, expected, context)
    end
  end
end
