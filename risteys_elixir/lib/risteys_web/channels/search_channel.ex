defmodule RisteysWeb.SearchChannel do
  use Phoenix.Channel

  # TODO put the data parsing somewhere in an agent/global state as we need it in different places
  @json "assets/data/myphenos.json" |> File.read!() |> Jason.decode!()

  def join("search", _message, socket) do
    {:ok, socket}
  end

  def handle_in("query", %{"body" => ""}, socket) do
    :ok = push(socket, "results", %{body: %{results: []}})
    {:noreply, socket}
  end

  def handle_in("query", %{"body" => user_input}, socket) do
    response = %{
      results: search(user_input)
    }

    :ok = push(socket, "results", %{body: response})
    {:noreply, socket}
  end

  def search(query) do
    loquery = String.downcase(query)

    # Merge results by phenocode
    # TODO this could refactored by passing the results dict to each function, building it up from %{}
    descriptions = match_desc(@json, loquery)
    icds = match_icd(@json, loquery)
    phenocodes = match_phenocode(@json, loquery)

    results =
      descriptions
      |> Map.merge(icds, fn _code, desc, icd ->
        Map.merge(desc, icd)
      end)
      |> Map.merge(phenocodes, fn _code, prev, phenocode ->
        Map.merge(prev, phenocode)
      end)

    # Provide a description for the results that match only on ICD or Phenocode
    results =
      for {code, map} <- results, into: %{} do
        map =
          if Map.has_key?(map, :description) do
            # The map has already a matching description with highlights, so keeping it.
            map
          else
            # Adding a description from the phenotypes base data
            desc =
              @json
              |> Map.fetch!(code)
              |> Map.fetch!("description")

            Map.put(map, :description, desc)
          end

        {code, map}
      end

    # Reshape data structure to send over websocket
    results =
      for {code, map} <- results do
        # TODO should use sthing like route_of(code) instead of hardcoded route
        Map.put(map, :url, "/code/" <> code)
      end

    results |> Enum.take(10)
  end

  defp match_desc(phenos, loquery) do
    for {code, %{"description" => desc}} <- phenos,
        desc |> String.downcase() |> String.contains?(loquery),
        into: %{} do
      hldesc = highlight(desc, loquery)
      {code, %{description: hldesc}}
    end
  end

  defp match_icd(phenos, loquery) do
    for {code, %{"icd_incl" => icds}} <- phenos,
        icds
        |> Enum.any?(fn icd ->
          icd |> String.downcase() |> String.contains?(loquery)
        end),
        into: %{} do
      icds =
        for icd <- icds,
            icd |> String.downcase() |> String.contains?(loquery) do
          highlight(icd, loquery)
        end

      {code, %{icds: icds}}
    end
  end

  defp match_phenocode(phenos, loquery) do
    for {code, _map} <- phenos,
        code |> String.downcase() |> String.contains?(loquery),
        into: %{} do
      hl_phenocode = highlight(code, loquery)
      {code, %{phenocode: hl_phenocode}}
    end
  end

  defp highlight(string, query) do
    # case insensitive match
    reg = Regex.compile!(query, "i")
    # TODO use EEX for templating / mixing html
    String.replace(string, reg, "<span class=\"highlight\">\\0</span>")
  end
end
