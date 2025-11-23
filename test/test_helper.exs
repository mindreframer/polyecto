# Start the test repo
{:ok, _} = PolyEcto.TestRepo.start_link()

# Run migrations
Ecto.Adapters.SQL.Sandbox.mode(PolyEcto.TestRepo, :manual)

ExUnit.start()
