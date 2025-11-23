defmodule PolyEcto.TestRepo do
  @moduledoc """
  Test repository for PolyEcto tests.
  """
  use Ecto.Repo,
    otp_app: :polyecto,
    adapter: Ecto.Adapters.Postgres
end
