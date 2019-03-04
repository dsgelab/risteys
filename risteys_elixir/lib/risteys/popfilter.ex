defmodule Risteys.Popfilter do
  def default_filters do
    %{
      "name" => "User defined sub-pop 1",
      "filters" => [
        %{
          "type" => "radio",
          "metric" => "sex",
          "text" => "Sex",
          "selected" => "any",
          "values" => %{
            "male" => %{
              "display" => "Male",
              "data" => [1]
            },
            "female" => %{
              "display" => "Female",
              "data" => [2]
            },
            "any" => %{
              "display" => "Any",
              "data" => [1, 2]
            }
          },
          "value_order" => ["any", "male", "female"]
        },
        %{
          "type" => "radio",
          "metric" => "smoking",
          "text" => "Smoking?",
          "selected" => "any",
          "values" => %{
            "yes" => %{
              "display" => "Yes",
              "data" => [true]
            },
            "no" => %{
              "display" => "No",
              "data" => [false]
            },
            "any" => %{
              "display" => "Any",
              "data" => [true, false]
            }
          }
        },
        %{
          "type" => "interval",
          "metric" => "bmi",
          "text" => "BMI",
          "values" => [nil, nil]
        },
        %{
          "type" => "interval",
          "metric" => "age",
          "text" => "Age",
          "values" => [nil, nil]
        },
        %{
          "type" => "interval",
          "metric" => "sbp",
          "text" => "SBP",
          "values" => [nil, nil]
        }
      ]
    }
  end

  def filters_to_func(filters) do
    Enum.reduce(filters, fn _ -> true end, fn filter, acc -> to_func(acc, filter) end)
  end

  defp to_func(acc, %{
         "type" => "radio",
         "metric" => metric,
         "values" => values,
         "selected" => selected
       }) do
    possible_values = values |> Map.fetch!(selected) |> Map.fetch!("data")
    filter = fn val -> val in possible_values end

    fn %{^metric => metric_value} = indiv ->
      acc.(indiv) and filter.(metric_value)
    end
  end

  defp to_func(acc, %{"type" => "interval", "metric" => metric, "values" => values}) do
    case values do
      [nil, nil] ->
        acc

      [nil, maxi] ->
        fn %{^metric => metric_value} = indiv ->
          acc.(indiv) and
            metric_value < maxi
        end

      [mini, nil] ->
        fn %{^metric => metric_value} = indiv ->
          acc.(indiv) and
            metric_value > mini
        end

      [mini, maxi] ->
        fn %{^metric => metric_value} = indiv ->
          acc.(indiv) and
            metric_value > mini and
            metric_value < maxi
        end
    end
  end
end
