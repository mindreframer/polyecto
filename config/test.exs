import Config

# Configure ecto repos for migrations
config :polyecto, ecto_repos: [PolyEcto.TestRepo]

# Configure test database
config :polyecto, PolyEcto.TestRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "polyecto_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  priv: "priv/repo"

# Print only warnings and errors during test
config :logger, level: :warning
