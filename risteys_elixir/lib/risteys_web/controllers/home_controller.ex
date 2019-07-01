defmodule RisteysWeb.HomeController do
  use RisteysWeb, :controller
  alias Risteys.Phenocode
  alias Risteys.Repo
  import Ecto.Query
  plug :put_layout, "minimal.html"

  def index(conn, _params) do
    {phenos_group1, phenos_group2} = get_demo_phenos()

    conn
    |> assign(:user_is_authenticated, get_session(conn, :user_is_authenticated))
    |> assign(:phenos_group1, phenos_group1)
    |> assign(:phenos_group2, phenos_group2)
    |> render("index.html")
  end

  defp get_demo_phenos() do
    # Get all the demo phenocodes and split them in 2 groups.
    phenos =
      Repo.all(from p in Phenocode, select: {p.name, p.tags, p.longname})
      |> Enum.filter(fn {_name, tags, _longname} ->
        "#DEMO" in String.split(tags, ",")
      end)
      |> Enum.sort_by(fn {_name, _tags, longname} -> longname end)

    split_at = ceil(length(phenos) / 2)
    {Enum.take(phenos, split_at), Enum.drop(phenos, split_at)}
  end
end
