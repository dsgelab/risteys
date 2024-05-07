defmodule Risteys.Utils do

  @doc """
  Schema validator to check that N is green data (nil or >= 5)
  """
  def is_green(field, value) do
    if is_nil(value) or value >= 5 do
      []
    else
      [{field, "#{field} must be nil or ≥5 but is #{value}."}]
    end
  end
end
