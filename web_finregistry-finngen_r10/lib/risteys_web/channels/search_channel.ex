defmodule RisteysWeb.SearchChannel do
  use Phoenix.Channel
  alias Risteys.{FGEndpoint, Repo, Icd10}
  alias RisteysWeb.Router.Helpers, as: Routes
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
      results: search(socket, user_input, 10)
    }

    :ok = push(socket, "results", %{body: response})
    {:noreply, socket}
  end

  defp search_icd10_code(user_query, limit) do
    pattern = "%" <> user_query <> "%"

    query =
      from endpoint in FGEndpoint.Definition,
        join: assoc in FGEndpoint.DefinitionICD10,
        on: endpoint.id == assoc.fg_endpoint_id,
        join: icd in Icd10,
        on: assoc.icd10_id == icd.id,
        where: ilike(icd.code, ^pattern),
        group_by: endpoint.name,
        select: %{name: endpoint.name, icds: fragment("array_agg(?)", icd.code)},
        limit: ^limit

    Repo.all(query)
    |> Enum.map(&struct_icd_code(&1))
  end

  defp struct_icd_code(%{name: name, icds: icds}) do
    %{
      name: name,
      # dedup ICDs
      icds: MapSet.new(icds) |> MapSet.to_list()
    }
  end

  defp search_endpoint_longname(user_query, limit) do
    pattern = "%" <> user_query <> "%"

    Repo.all(
      from endpoint in FGEndpoint.Definition,
        where: ilike(endpoint.longname, ^pattern),
        select: %{name: endpoint.name, longname: endpoint.longname},
        limit: ^limit
    )
  end

  defp search_description(user_query, limit) do
    pattern = "%" <> user_query <> "%"

    query =
      from endpoint in FGEndpoint.Definition,
        where: ilike(endpoint.description, ^pattern),
        select: %{name: endpoint.name, description: endpoint.description},
        limit: ^limit

    Repo.all(query)
    |> Enum.map(fn res -> struct_description(res, user_query) end)
  end

  # Show only sentences that have the user query in it.
  defp struct_description(%{name: name, description: description}, user_query) do
    description =
      description
      |> String.split(".")
      |> Enum.filter(fn sentence -> String.contains?(sentence, user_query) end)
      |> Enum.intersperse("…")
      |> Enum.join("")

    %{name: name, description: description}
  end

  defp search_endpoint_name(user_query, limit) do
    pattern = "%" <> user_query <> "%"

    query =
      from endpoint in FGEndpoint.Definition,
        select: %{name: endpoint.name, longname: endpoint.longname},
        where: ilike(endpoint.name, ^pattern),
        limit: ^limit

    Repo.all(query)
  end

  defp search(socket, user_query, limit) do
    # 1. Get matches from the database
    icds = search_icd10_code(user_query, limit)
    endpoint_longnames = search_endpoint_longname(user_query, limit)
    descriptions = search_description(user_query, limit)
    endpoint_names = search_endpoint_name(user_query, limit)

    # 2. Structure the output to be sent over the channel
    icds = [
      "ICD-10 code",
      Enum.map(icds, fn %{icds: icds, name: name} ->
        icds = Enum.join(icds, ", ")
        icds = highlight(icds, user_query)
        %{endpoint: name, content: icds, url: url(socket, name)}
      end)
    ]

    endpoint_longnames = [
      "Endpoint long name",
      Enum.map(endpoint_longnames, fn %{name: name, longname: longname} ->
        hlname = highlight(name, user_query)
        hllongname = highlight(longname, user_query)
        %{endpoint: hlname, content: hllongname, url: url(socket, name)}
      end)
    ]

    descriptions = [
      "Description",
      Enum.map(descriptions, fn %{name: name, description: description} ->
        hldesc = highlight(description, user_query)
        %{endpoint: name, content: hldesc, url: url(socket, name)}
      end)
    ]

    endpoint_names = [
      "Endpoint name",
      Enum.map(endpoint_names, fn %{name: name, longname: longname} ->
        hlname = highlight(name, user_query)
        %{endpoint: hlname, content: longname, url: url(socket, name)}
      end)
    ]

    [endpoint_longnames, icds, descriptions, endpoint_names]
    |> Enum.reject(fn [_category, list] -> Enum.empty?(list) end)
  end

  defp url(conn, code) do
    Routes.fg_endpoint_path(conn, :show, code)
  end

  defp highlight(string, query) do
    # case insensitive match
    reg = Regex.compile!(query, "i")
    String.replace(string, reg, "<span class=\"highlight\">\\0</span>")
  end
end
