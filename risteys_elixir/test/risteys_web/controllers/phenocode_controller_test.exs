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
        prior_id: a1.id,
        outcome_id: a2.id,
        lagged_hr_cut_year: 0,
        hr: 0.0,
        ci_min: 0.0,
        ci_max: 10.0,
        n_individuals: 100,
        pvalue: 0.1
      })
      |> Risteys.Repo.insert!()

      # Making the JSON API request
      conn = Plug.Test.init_test_session(conn, user_is_authenticated: true)
      conn = get(conn, Routes.phenocode_path(conn, :get_assocs_json, "A1"))
      response = json_response(conn, 200)

      # Testing both:
      # - the general structure of the response using pattern matching (raises an error if fails).
      # - some values from the response
      %{
        "plot" => _,
        "table" => _
      } = response

      [
        %{
          "ci_min" => "0.00",
          "ci_max" => "10.00",
          "hr" => 0.0,
          "hr_str" => "0.00",
          "longname" => "Longname for A2",
          "name" => "A2",
          "nindivs" => 100,
          "pvalue_num" => 0.1,
          "pvalue_str" => "1.0e-1"
        }
      ] = response["plot"]

      [
        %{
          "all" => %{
            "after" => %{
              "ci_min" => "0.00",
              "ci_max" => "10.00",
              "hr" => 0.0,
              "hr_str" => "0.00",
              "nindivs" => 100,
              "pvalue" => 0.1,
              "pvalue_str" => "1.0e-1"
            },
            "before" => _
          },
          "lagged_1y" => %{
            "after" => _,
            "before" => _
          },
          "lagged_5y" => %{
            "after" => _,
            "before" => _
          },
          "lagged_15y" => %{
            "after" => _,
            "before" => _
          },
          "longname" => "Longname for A2",
          "name" => "A2"
        }
      ] = response["table"]
    end
  end
end
