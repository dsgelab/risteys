defmodule Risteys.PopfilterTest do
  use ExUnit.Case

  @fake_indivs [
    %{
      "smoking" => true,
      "bmi" => 12
    },
    %{
      "smoking" => false,
      "bmi" => 40
    },
    %{
      "smoking" => false,
      "bmi" => 30
    }
  ]

  test "radio(all) filter" do
    filters = [
      %{
        "type" => "radio",
        "metric" => "smoking",
        "text" => "Smoking?",
        "values" => %{
          "yes" => %{
            "display" => "Yes",
            "data" => [true]
          },
          "no" => %{
            "display" => "No",
            "data" => [false]
          },
          "all" => %{
            "display" => "All",
            "data" => [true, false]
          }
        },
        "value_order" => ["yes", "no", "all"],
        "selected" => "all"
      }
    ]

    func = Risteys.Popfilter.filters_to_func(filters)

    assert(
      Enum.filter(@fake_indivs, func) ==
        @fake_indivs
    )
  end

  test "radio(yes) filter" do
    filters = [
      %{
        "type" => "radio",
        "metric" => "smoking",
        "text" => "Smoking?",
        "values" => %{
          "yes" => %{
            "display" => "Yes",
            "data" => [true]
          },
          "no" => %{
            "display" => "No",
            "data" => [false]
          },
          "all" => %{
            "display" => "All",
            "data" => [true, false]
          }
        },
        "value_order" => ["yes", "no", "all"],
        "selected" => "yes"
      }
    ]

    func = Risteys.Popfilter.filters_to_func(filters)

    expected = [
      %{
        "smoking" => true,
        "bmi" => 12
      }
    ]

    assert(Enum.filter(@fake_indivs, func) == expected)
  end

  test "radio(no) filter" do
    filters = [
      %{
        "type" => "radio",
        "metric" => "smoking",
        "text" => "Smoking?",
        "values" => %{
          "yes" => %{
            "display" => "Yes",
            "data" => [true]
          },
          "no" => %{
            "display" => "No",
            "data" => [false]
          },
          "all" => %{
            "display" => "All",
            "data" => [true, false]
          }
        },
        "value_order" => ["yes", "no", "all"],
        "selected" => "no"
      }
    ]

    func = Risteys.Popfilter.filters_to_func(filters)

    expected = [
      %{
        "smoking" => false,
        "bmi" => 40
      },
      %{
        "smoking" => false,
        "bmi" => 30
      }
    ]

    assert(Enum.filter(@fake_indivs, func) == expected)
  end

  test "interval filter" do
    filters = [
      %{
        "type" => "interval",
        "metric" => "bmi",
        "text" => "BMI",
        "values" => [20, nil]
      }
    ]

    func = Risteys.Popfilter.filters_to_func(filters)

    expected = [
      %{
        "smoking" => false,
        "bmi" => 40
      },
      %{
        "smoking" => false,
        "bmi" => 30
      }
    ]

    assert(
      Enum.filter(@fake_indivs, func) ==
        expected
    )
  end

  test "many filters" do
    filters = [
      %{
        "type" => "radio",
        "metric" => "smoking",
        "text" => "Smoking?",
        "values" => %{
          "yes" => %{
            "display" => "Yes",
            "data" => [true]
          },
          "no" => %{
            "display" => "No",
            "data" => [false]
          },
          "all" => %{
            "display" => "All",
            "data" => [true, false]
          }
        },
        "value_order" => ["yes", "no", "all"],
        "selected" => "no"
      },
      %{
        "type" => "interval",
        "metric" => "bmi",
        "text" => "BMI",
        "values" => [nil, 35]
      }
    ]

    expected = [
      %{
        "smoking" => false,
        "bmi" => 30
      }
    ]

    func = Risteys.Popfilter.filters_to_func(filters)
    assert(Enum.filter(@fake_indivs, func) == expected)
  end
end
