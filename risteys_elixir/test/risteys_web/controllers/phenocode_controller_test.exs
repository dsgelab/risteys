defmodule RisteysWeb.PhenocodeControllerTest do
  use RisteysWeb.ConnCase

  alias Risteys.Repo
  alias Risteys.Phenocode
  alias Risteys.CoxHR

  describe "JSON API" do
    test "lists associations as JSON", %{conn: conn} do
      # Make a fake association for testing purpose
      Risteys.DataCase.data_fixture("A1")
      Risteys.DataCase.data_fixture("A2")
      a1 = Repo.get_by(Phenocode, name: "A1")
      a2 = Repo.get_by(Phenocode, name: "A2")

      CoxHR.changeset(%CoxHR{}, %{
        ci_max: 0.0,
        ci_min: 0.0,
        hr: 0.0,
        n_individuals: 100,
        prior_id: a1.id,
        pvalue: 0.0,
        outcome_id: a2.id
      })
      |> Risteys.Repo.insert!()

      # Making the JSON API request
      conn = Plug.Test.init_test_session(conn, user_is_authenticated: true)
      conn = get(conn, Routes.phenocode_path(conn, :get_assocs, "A1"))
      response = json_response(conn, 200)

      # Checking for reponse format and values
      assert response == [
               %{
                 "name" => "A2",
                 "longname" => "Longname for A2",
                 "category" => "test",
                 "direction" => "after",
                 "hr" => 0.0,
                 "ci_min" => 0.0,
                 "ci_max" => 0.0,
                 "pvalue_str" => "0.0e+0",
                 "pvalue_num" => 0.0,
                 "nindivs" => 100
               }
             ]
    end
  end
end
