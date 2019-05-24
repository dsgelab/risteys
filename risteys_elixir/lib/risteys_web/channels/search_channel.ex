defmodule RisteysWeb.SearchChannel do
  use Phoenix.Channel
  alias Risteys.{Repo, Phenocode, Icd10, PhenocodeIcd10}
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
      from p in Phenocode,
        join: assoc in PhenocodeIcd10,
        on: p.id == assoc.phenocode_id,
        join: icd in Icd10,
        on: assoc.icd10_id == icd.id,
        where: ilike(icd.code, ^pattern),
        group_by: p.name,
        select: %{name: p.name, icds: fragment("array_agg(?)", icd.code)},
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

  defp search_phenocode_longname(user_query, limit) do
    pattern = "%" <> user_query <> "%"

    Repo.all(
      from p in Phenocode,
        where: ilike(p.longname, ^pattern),
        select: %{name: p.name, longname: p.longname},
        limit: ^limit
    )
  end

  defp search_description(user_query, limit) do
    pattern = "%" <> user_query <> "%"

    query =
      from p in Phenocode,
        where: ilike(p.description, ^pattern),
        select: %{name: p.name, description: p.description},
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

  defp search_phenocode_name(user_query, limit) do
    pattern = "%" <> user_query <> "%"

    query =
      from p in Phenocode,
        select: %{name: p.name, longname: p.longname},
        where: ilike(p.name, ^pattern),
        limit: ^limit

    Repo.all(query)
  end

  defp search(socket, user_query, limit) do
    # 1. Get matches from the database
    icds = search_icd10_code(user_query, limit)
    phenocode_longnames = search_phenocode_longname(user_query, limit)
    descriptions = search_description(user_query, limit)
    phenocode_names = search_phenocode_name(user_query, limit)

    # 2. Structure the output to be sent over the channel
    icds = [
      "ICD-10 code",
      Enum.map(icds, fn %{icds: icds, name: name} ->
        icds = Enum.join(icds, ", ")
        icds = highlight(icds, user_query)
        %{phenocode: name, content: icds, url: url(socket, name)}
      end)
    ]

    phenocode_longnames = [
      "Phenocode long name",
      Enum.map(phenocode_longnames, fn %{name: name, longname: longname} ->
        hlname = highlight(name, user_query)
        hllongname = highlight(longname, user_query)
        %{phenocode: hlname, content: hllongname, url: url(socket, name)}
      end)
    ]

    descriptions = [
      "Description",
      Enum.map(descriptions, fn %{name: name, description: description} ->
        hldesc = highlight(description, user_query)
        %{phenocode: name, content: hldesc, url: url(socket, name)}
      end)
    ]

    phenocode_names = [
      "Phenocode name",
      Enum.map(phenocode_names, fn %{name: name, longname: longname} ->
        hlname = highlight(name, user_query)
        %{phenocode: hlname, content: longname, url: url(socket, name)}
      end)
    ]

    [phenocode_longnames, icds, descriptions, phenocode_names]
    |> Enum.reject(fn [_category, list] -> Enum.empty?(list) end)
  end

  defp url(conn, code) do
    Routes.phenocode_path(conn, :show, code)
  end

  defp highlight(string, query) do
    # case insensitive match
    reg = Regex.compile!(query, "i")
    String.replace(string, reg, "<span class=\"highlight\">\\0</span>")
  end
end
