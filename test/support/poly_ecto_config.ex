defmodule PolyEctoTest.Config do
  @moduledoc """
  Test configuration for PolyEcto.

  Provides a simple registry mapping for test schemas.
  """

  @behaviour PolyEcto.Config

  @registry %{
    "test_cards" => PolyEctoTest.TestCard,
    "test_comments" => PolyEctoTest.TestComment,
    "test_posts" => PolyEctoTest.TestPost
  }

  @reverse_registry Map.new(@registry, fn {k, v} -> {v, k} end)

  @impl true
  def repo, do: PolyEcto.TestRepo

  @impl true
  def get_schema(table_name), do: Map.get(@registry, table_name)

  @impl true
  def get_table(schema_module), do: Map.get(@reverse_registry, schema_module)
end
