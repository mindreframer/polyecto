defmodule PolyEcto.Config do
  @moduledoc """
  Configuration behavior for PolyEcto.

  Implement this behavior to provide:
  - The Ecto.Repo module to use for queries
  - A registry mapping table names to schema modules
  - A reverse mapping from schema modules to table names

  ## Example

      defmodule MyApp.PolyEctoConfig do
        @behaviour PolyEcto.Config

        @registry %{
          "posts" => MyApp.Post,
          "comments" => MyApp.Comment
        }

        @reverse_registry Map.new(@registry, fn {k, v} -> {v, k} end)

        @impl true
        def repo, do: MyApp.Repo

        @impl true
        def get_schema(table_name), do: Map.get(@registry, table_name)

        @impl true
        def get_table(schema_module), do: Map.get(@reverse_registry, schema_module)
      end

  Then configure in `config/config.exs`:

      config :polyecto, :config, MyApp.PolyEctoConfig
  """

  @doc """
  Returns the Ecto.Repo module to use for database operations.
  """
  @callback repo() :: module()

  @doc """
  Returns the schema module for a given table name.

  Returns `nil` if the table is not registered.
  """
  @callback get_schema(table_name :: String.t()) :: module() | nil

  @doc """
  Returns the table name for a given schema module.

  Returns `nil` if the module is not registered.
  """
  @callback get_table(schema_module :: module()) :: String.t() | nil
end
