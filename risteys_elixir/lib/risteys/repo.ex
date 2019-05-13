defmodule Risteys.Repo do
  use Ecto.Repo,
    otp_app: :risteys,
    adapter: Ecto.Adapters.Postgres
  require Logger

  @doc """
  Try to update the given changeset.

  On failure: log the error and return the non-updated struct.
  On success: return the updated struct.
  """
  def try_update(struct, changeset) do
    case Risteys.Repo.update(changeset) do
      {:ok, struct} ->
	Logger.debug("update ok for changeset: #{inspect(changeset)}")
	struct

      {:error, changeset} ->
	Logger.warn(inspect(changeset))
	struct
    end
  end
end
