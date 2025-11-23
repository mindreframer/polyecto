defmodule PolyEcto.BelongsTo do
  @moduledoc false

  import Ecto.Changeset
  import Ecto.Query
  alias PolyEcto.Helpers

  @doc """
  Casts a polymorphic belongs_to association in a changeset.

  When a struct is assigned to the polymorphic virtual field, this function
  extracts the table name and ID, then stores them in the appropriate fields.

  ## Examples

      comment
      |> cast(attrs, [:content])
      |> cast_polymorphic(:commentable)
  """
  @spec cast_polymorphic(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def cast_polymorphic(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      %{__struct__: module} = struct ->
        config = changeset.data.__struct__.__polyecto_belongs_to__(field)
        table = Helpers.get_table_name(module)
        id = Helpers.get_primary_key_value(struct)

        changeset
        |> put_change(config.table_field, table)
        |> put_change(config.id_field, to_string(id))
        |> delete_change(field)
    end
  end

  @doc """
  Loads a polymorphic belongs_to association for a single record.

  Reads the table name and ID from the record, queries the appropriate entity,
  and sets it in the virtual field.

  ## Examples

      comment = Repo.get!(Comment, 1)
      |> PolyEcto.load_polymorphic(:commentable)

      comment.commentable # => %Post{...}
  """
  @spec load_polymorphic(struct(), atom()) :: struct()
  def load_polymorphic(record, field) do
    module = record.__struct__
    config = module.__polyecto_belongs_to__(field)

    table_name = Map.get(record, config.table_field)
    id = Map.get(record, config.id_field)

    entity =
      case {table_name, id} do
        {nil, _} ->
          nil

        {_, nil} ->
          nil

        {table, id_value} ->
          case Helpers.get_schema(table) do
            nil ->
              nil

            schema_module ->
              Helpers.repo().get(schema_module, id_value)
          end
      end

    Map.put(record, field, entity)
  end

  @doc """
  Batch preloads polymorphic belongs_to associations for multiple records.

  Groups records by table name, performs a single query per table, then maps
  entities back to records. This prevents N+1 queries.

  ## Examples

      comments = Repo.all(Comment)
      |> PolyEcto.preload_polymorphic(:commentable)

      Enum.each(comments, fn c -> IO.inspect(c.commentable) end)
  """
  @spec preload_polymorphic([struct()], atom()) :: [struct()]
  def preload_polymorphic([], _field), do: []

  def preload_polymorphic(records, field) when is_list(records) do
    [first | _] = records
    module = first.__struct__
    config = module.__polyecto_belongs_to__(field)

    # Group records by table name
    grouped =
      records
      |> Enum.group_by(fn record ->
        Map.get(record, config.table_field)
      end)

    # Load entities for each table
    entities_by_table =
      grouped
      |> Enum.reduce(%{}, fn {table_name, table_records}, acc ->
        case table_name do
          nil ->
            acc

          table ->
            case Helpers.get_schema(table) do
              nil ->
                acc

              schema_module ->
                ids =
                  table_records
                  |> Enum.map(&Map.get(&1, config.id_field))
                  |> Enum.reject(&is_nil/1)

                if Enum.empty?(ids) do
                  acc
                else
                  entities =
                    from(s in schema_module, where: field(s, :id) in ^ids)
                    |> Helpers.repo().all()

                  entity_map =
                    Map.new(entities, fn entity ->
                      id = Helpers.get_primary_key_value(entity)
                      {to_string(id), entity}
                    end)

                  Map.put(acc, table, entity_map)
                end
            end
        end
      end)

    # Map entities back to records
    records
    |> Enum.map(fn record ->
      table = Map.get(record, config.table_field)
      id = Map.get(record, config.id_field)

      entity =
        case {table, id} do
          {nil, _} ->
            nil

          {_, nil} ->
            nil

          {t, i} ->
            entities_by_table
            |> Map.get(t, %{})
            |> Map.get(i)
        end

      Map.put(record, field, entity)
    end)
  end

  def preload_polymorphic(record, field) when is_struct(record) do
    [record]
    |> preload_polymorphic(field)
    |> List.first()
  end
end
