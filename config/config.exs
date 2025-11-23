import Config

# Configure PolyEcto with test config (only used in tests)
if config_env() == :test do
  config :polyecto, :config, PolyEctoTest.Config
end

# Import environment specific config
import_config "#{config_env()}.exs"
