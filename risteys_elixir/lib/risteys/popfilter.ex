defmodule Risteys.Popfilter do
  def default_filters do
    %{
      "name" => "User defined sub-pop 1",
      "filters" => [
        %{
          "type" => "radio",
          "metric" => "sex",
          "text" => "Sex",
          "selected" => nil
        },
        %{
          "type" => "radio",
          "metric" => "smoking",
          "text" => "Smoking?",
          "selected" => nil
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

  defp to_func(acc, %{"type" => "radio", "metric" => metric, "selected" => selected}) do
    if is_nil(selected) do
      acc
    else
      fn %{^metric => metric_value} = indiv ->
        acc.(indiv) and metric_value == selected
      end
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
