defmodule Risteys.Utils do

  @doc """
  Schema validator to check that N is green data (N >= 5)
  """
  def is_green(field, value) do
    if value >= 5 do
      []
    else
      [{field, "#{field} must be ≥5 but is #{value}."}]
    end
  end
end
