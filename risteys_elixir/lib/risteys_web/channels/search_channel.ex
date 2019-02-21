defmodule RisteysWeb.SearchChannel do
  use Phoenix.Channel

  # TODO put the data parsing somewhere in an agent/global state as we need it in different places
  @json "assets/data/myphenos.json" |> File.read! |> Jason.decode!

  def join("search", _message, socket) do
    {:ok, socket}
  end

  def handle_in("query", %{"body" => ""}, socket) do
  	:ok = push(socket, "result", %{body: %{results: []}})
  	{:noreply, socket}
  end
  def handle_in("query", %{"body" => user_input}, socket) do
  	response = %{
  		results: [
  			%{
  				title: "Finngen endpoints",
  				hlitems: search(user_input)
  			}
  		]
  	}
    :ok = push(socket, "result", %{body: response})
    {:noreply, socket}
  end

  defp search(query) do
  	@json
  	|> Map.values 
  	|> Enum.map(fn dict -> Map.fetch!(dict, "description") end) 
  	|> Enum.filter(fn desc ->
  		String.contains?(desc |> String.downcase, query |> String.downcase) end)
  	|> Enum.map(fn match -> highlight(match, query |> String.downcase) end)
  end

  defp highlight(string, query) do
  	reg = Regex.compile!(query, "i")  # case insensitive match
  	String.replace(string, reg, "<span class=\"highlight\">\\0</span>")
  end
end
