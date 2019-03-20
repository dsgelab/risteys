defmodule RisteysWeb.SearchChannel do
  use Phoenix.Channel
  alias Risteys.{Repo, Phenocode}
  import Ecto.Query

  def join("search", _message, socket) do
    {:ok, socket}
  end

  def handle_in("query", %{"body" => ""}, socket) do
    :ok = push(socket, "results", %{body: %{results: []}})
    {:noreply, socket}
  end

  def handle_in("query", %{"body" => user_input}, socket) do
    response = %{
      results: search(user_input, 10)
    }

    :ok = push(socket, "results", %{body: response})
    {:noreply, socket}
  end

  def search(user_query, limit) do
    pattern = "%" <> user_query <> "%"

    Repo.all(
      from p in Phenocode,
        where:
          ilike(p.code, ^pattern) or
            ilike(p.longname, ^pattern),
        limit: ^limit
    )
    |> Enum.map(fn %Phenocode{
                     code: code,
                     longname: description,
                     hd_codes: hd_codes,
                     cod_codes: cod_codes
                   } ->
      url = "/code/" <> code

      %{
        description: description |> highlight(user_query),
        phenocode: code |> highlight(user_query),
        url: url
      }
    end)
  end

  defp highlight(string, query) do
    # case insensitive match
    reg = Regex.compile!(query, "i")
    # TODO use EEX for templating / mixing html
    String.replace(string, reg, "<span class=\"highlight\">\\0</span>")
  end
end
