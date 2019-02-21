defmodule RisteysWeb.CodeView do
  use RisteysWeb, :view
  
  def prevalence(cases, controls) do
    "#{trunc(cases / (cases + controls) * 100)}%"
  end
end
