defmodule RisteysWeb.CodeController do
  use RisteysWeb, :controller
  alias Risteys.{Repo, Phenocode}
  import Ecto.Query

  def show(conn, %{"phenocode" => code}) do
    %Phenocode{longname: title, hd_codes: hd_codes, cod_codes: cod_codes} =
      Repo.one(from p in Phenocode, where: p.code == ^code)

    conn
    |> assign(:code, code)
    |> assign(:title, title)
    |> assign(:hd_codes, hd_codes)
    |> assign(:cod_codes, cod_codes)
    |> render("show.html")
  end
end
