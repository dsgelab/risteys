defmodule Risteys.FGEndpoint.StatsCumulativeIncidence do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stats_cumulative_incidence" do
    field :fg_endpoint_id, :id

    field :age, :float
    field :sex, :string
    field :value, :float

    timestamps()
  end

  @doc false
  def changeset(stats_cumulative_incidence, attrs) do
    stats_cumulative_incidence
    |> cast(attrs, [:fg_endpoint_id, :age, :sex, :value])
    |> validate_required([:fg_endpoint_id, :age, :sex, :value])
    |> validate_number(:age, greater_than_or_equal_to: 0.0)
    |> validate_change(:value, &check_incidence/2)
    |> validate_inclusion(:sex, ["male", "female"])
    |> unique_constraint(:fg_endpoint_id, name: :cumulinc)  # unique on (fg_endpoint, sex, age)
  end

  # Incidence must have a limited precision (to have xx.xx%) and be in [0, 1]
  defp check_incidence(field, number) do
    n_length =
      number
      |> Float.to_string()
      |> String.length()

    # 0.1234 has length 6
    is_truncated = n_length <= 6
    is_in_range = number >= 0.0 and number <= 1.0

    if is_truncated and is_in_range do
      # no error
      []
    else
      [{field, "value out of range [0, 1] or incorrect float format: #{number}"}]
    end
  end
end
