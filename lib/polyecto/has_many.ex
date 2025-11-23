defmodule PolyEcto.HasMany do
  @moduledoc false

  import Ecto.Query
  alias PolyEcto.Helpers

  @doc """
  Builds an Ecto.Query for polymorphic has_many associations.

  Returns a query that filters by the parent's table name and ID.
  The query can be further composed with additional filters.

  ## Examples

      post = Repo.get!(Post, 1)
      query = PolyEcto.polymorphic_assoc(post, :comments)
      comments = Repo.all(query)

      # Compose with additional filters
      recent_comments =
        PolyEcto.polymorphic_assoc(post, :comments)
        |> where([c], c.inserted_at > ago(7, "day"))
        |> Repo.all()
  """
  @spec polymorphic_assoc(struct(), atom()) :: Ecto.Query.t()
  def polymorphic_assoc(struct, field) do
    module = struct.__struct__
    config = module.__polyecto_has_many__(field)

    table = Helpers.get_table_name(module)
    id = Helpers.get_primary_key_value(struct)

    table_field = :"#{config.as}_table"
    id_field = :"#{config.as}_id"

    from(q in config.queryable,
      where: field(q, ^table_field) == ^table,
      where: field(q, ^id_field) == ^to_string(id)
    )
  end

  @doc """
  Preloads polymorphic has_many associations for records.

  Accepts either a single struct or a list of structs. For lists, performs
  a single query to load all associations, then maps them back to parent
  records. This prevents N+1 queries.

  ## Examples

      # Single record
      post = Repo.get!(Post, 1)
      |> PolyEcto.preload_polymorphic_assoc(:comments)

      # Multiple records
      posts = Repo.all(Post)
      |> PolyEcto.preload_polymorphic_assoc(:comments)

      Enum.each(posts, fn p -> IO.inspect(length(p.comments)) end)
  """
  @spec preload_polymorphic_assoc([struct()] | struct(), atom()) :: [struct()] | struct()
  def preload_polymorphic_assoc([], _field), do: []

  def preload_polymorphic_assoc(records, field) when is_list(records) do
    [first | _] = records
    module = first.__struct__
    config = module.__polyecto_has_many__(field)

    # Get table name for this entity type
    table = Helpers.get_table_name(module)

    # Collect all parent IDs
    ids =
      records
      |> Enum.map(&Helpers.get_primary_key_value/1)
      |> Enum.map(&to_string/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(ids) do
      # Return records with empty associations
      Enum.map(records, fn record -> Map.put(record, field, []) end)
    else
      # Query all related records
      table_field = :"#{config.as}_table"
      id_field = :"#{config.as}_id"

      related_records =
        from(q in config.queryable,
          where: field(q, ^table_field) == ^table,
          where: field(q, ^id_field) in ^ids
        )
        |> Helpers.repo().all()

      # Group by parent ID
      grouped_by_parent =
        related_records
        |> Enum.group_by(fn record ->
          Map.get(record, id_field)
        end)

      # Map back to parent records
      records
      |> Enum.map(fn record ->
        parent_id = record |> Helpers.get_primary_key_value() |> to_string()
        associations = Map.get(grouped_by_parent, parent_id, [])
        Map.put(record, field, associations)
      end)
    end
  end

  def preload_polymorphic_assoc(record, field) when is_struct(record) do
    [record]
    |> preload_polymorphic_assoc(field)
    |> List.first()
  end
end
