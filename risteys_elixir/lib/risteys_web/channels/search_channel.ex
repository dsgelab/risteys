defmodule RisteysWeb.SearchChannel do
  use Phoenix.Channel
  alias Risteys.{Repo, Phenocode}
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

  defp search_icd_code(user_query, limit) do
    Repo.all(
      from p in Phenocode,
        where:
          ^user_query in p.hd_icd_10 or
            ^user_query in p.hd_icd_9 or
            ^user_query in p.cod_icd_10 or
            ^user_query in p.cod_icd_9 or
            ^user_query in p.kela_reimb_icd,
        limit: ^limit
    )
    |> struct_icd_code()
  end

  defp struct_icd_code(phenocodes) do
    Enum.map(phenocodes, fn %Phenocode{
                              code: code,
                              hd_icd_10: hd_icd_10,
                              hd_icd_9: hd_icd_9,
                              cod_icd_10: cod_icd_10,
                              cod_icd_9: cod_icd_9,
                              kela_reimb_icd: kela_reimb_icd
                            } ->
      icds = hd_icd_10 ++ hd_icd_9 ++ cod_icd_10 ++ cod_icd_9 ++ kela_reimb_icd
      icds = MapSet.new(icds)

      %{
        icds: icds,
        code: code
      }
    end)
  end

  defp search_phenocode_code(user_query, limit) do
    pattern = "%" <> user_query <> "%"

    Repo.all(
      from p in Phenocode,
        where: ilike(p.code, ^pattern),
        select: %{code: p.code, name: p.longname},
        limit: ^limit
    )
  end

  defp search_phenocode_name(user_query, limit) do
    pattern = "%" <> user_query <> "%"

    Repo.all(
      from p in Phenocode,
        where: ilike(p.longname, ^pattern),
        select: %{code: p.code, name: p.longname},
        limit: ^limit
    )
  end

  defp search(socket, user_query, limit) do
    # 1. Get matches from the database
    icds = search_icd_code(user_query, limit)
    pheno_codes = search_phenocode_code(user_query, limit)
    pheno_names = search_phenocode_name(user_query, limit)

    # 2. Structure the output to be sent over the channel
    icds = [
      "ICD-10 code",
      Enum.map(icds, fn %{icds: icds, code: phenocode} ->
        icds = Enum.join(icds, ", ")
        icds = highlight(icds, user_query)
        %{phenocode: phenocode, content: icds, url: url(socket, phenocode)}
      end)
    ]

    pheno_codes = [
      "Phenocode code",
      Enum.map(pheno_codes, fn %{code: code, name: name} ->
        hlcode = highlight(code, user_query)
        %{phenocode: hlcode, content: name, url: url(socket, code)}
      end)
    ]

    pheno_names = [
      "Phenocode name",
      Enum.map(pheno_names, fn %{code: code, name: name} ->
        name = highlight(name, user_query)
        %{phenocode: code, content: name, url: url(socket, code)}
      end)
    ]

    [icds, pheno_codes, pheno_names]
    |> Enum.reject(fn [_category, list] -> Enum.empty?(list) end)
  end

  defp url(conn, code) do
    Routes.code_path(conn, :show, code)
  end

  defp highlight(string, query) do
    # case insensitive match
    reg = Regex.compile!(query, "i")
    String.replace(string, reg, "<span class=\"highlight\">\\0</span>")
  end
end
