defmodule RisteysWeb.Utils do

  @doc """
  Custom sorter that puts nil values at the end.
  To be used as the sorter of Enum.sort_by/3
  """
  def sorter_nil_end(direction) do
    fn aa, bb ->
      case {aa, bb, direction} do
        {nil, _, _} -> false
        {_, nil, _} -> true
        {_, _, :asc} -> aa < bb
        {_, _, :desc} -> aa > bb
      end
    end
  end

  @doc """
  Generate a pair of asc/desc sorting button for a Live View.
  """
  def sorter_buttons(column, form_id, active_sorter) do
    [
      gen_button(:asc, column, form_id, active_sorter),
      gen_button(:desc, column, form_id, active_sorter)
    ]
  end

  defp gen_button(direction, column, form_id, active_sorter) do
    content =
      case direction do
        :asc ->
          "▲"

        :desc ->
          "▼"
      end

    value =
      case direction do
        :asc ->
          column <> "_asc"

        :desc ->
          column <> "_desc"
      end

    class =
      case {direction, active_sorter} do
        {:asc, ^value} ->
          "radio-left active"

        {:asc, _} ->
          "radio-left"

        {:desc, ^value} ->
          "radio-right active"

        {:desc, _} ->
          "radio-right"
      end

    Phoenix.HTML.Tag.content_tag(
      :button,
      content,
      name: "sorter",
      value: value,
      form: form_id,
      class: class
    )
  end
end