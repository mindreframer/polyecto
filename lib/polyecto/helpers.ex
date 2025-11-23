defmodule PolyEcto.Helpers do
  @moduledoc false

  @doc """
  Returns the configured Ecto.Repo module.
  """
  @spec repo() :: module()
  def repo do
    PolyEcto.config().repo()
  end

  @doc """
  Returns the schema module for a given table name.

  Uses the configured registry to look up the mapping.

  ## Examples

      iex> get_schema("posts")
      MyApp.Post

      iex> get_schema("unknown_table")
      nil
  """
  @spec get_schema(String.t()) :: module() | nil
  def get_schema(table_name) do
    PolyEcto.config().get_schema(table_name)
  end

  @doc """
  Returns the table name for a given schema module.

  First checks the configured registry, then falls back to the schema's source.

  ## Examples

      iex> get_table_name(MyApp.Post)
      "posts"
  """
  @spec get_table_name(module()) :: String.t()
  def get_table_name(module) do
    PolyEcto.config().get_table(module) || module.__schema__(:source)
  end

  @doc """
  Extracts the primary key value from a struct.

  Uses the first primary key field defined in the schema.

  ## Examples

      iex> get_primary_key_value(%Post{id: "post_123"})
      "post_123"
  """
  @spec get_primary_key_value(struct()) :: any()
  def get_primary_key_value(struct) do
    [pk | _] = struct.__struct__.__schema__(:primary_key)
    Map.get(struct, pk)
  end
end
