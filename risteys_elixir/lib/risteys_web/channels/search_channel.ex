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
  	loquery = String.downcase(query)

  	@json
  	|> Enum.filter(fn {_code, %{"description" => desc}} ->
  		# Filter out the results that do not match
  		desc
  		|> String.downcase
  		|> String.contains?(loquery)
  	end)
	|> Enum.map(fn {code, %{"description" => desc}} ->
		# Transform data structure and apply highlighting
		%{
			html: highlight(desc, query),
			url: "/code/" <> code  # TODO use something like route_for(code) instead of hardcoded URL
		}
	end)
  end

  defp highlight(string, query) do
  	reg = Regex.compile!(query, "i")  # case insensitive match
  	String.replace(string, reg, "<span class=\"highlight\">\\0</span>")
  end
end
