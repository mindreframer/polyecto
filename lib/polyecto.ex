defmodule PolyEcto do
  @moduledoc """
  Polymorphic associations for Ecto.

  PolyEcto provides a generic, configurable system for polymorphic associations
  in Ecto schemas. It supports both `belongs_to` and `has_many` polymorphic
  relationships.

  ## Configuration

  First, create a config module implementing `PolyEcto.Config`:

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

  Then configure it in `config/config.exs`:

      config :polyecto, :config, MyApp.PolyEctoConfig

  ## Usage: Polymorphic Belongs To

  Define a schema with a polymorphic belongs_to:

      defmodule Comment do
        use Ecto.Schema
        import PolyEcto

        schema "comments" do
          polymorphic_belongs_to :commentable
          field :content, :string
          timestamps()
        end

        def changeset(comment, attrs) do
          comment
          |> cast(attrs, [:content])
          |> PolyEcto.cast_polymorphic(:commentable)
        end
      end

  Create a comment:

      post = Repo.get!(Post, 1)
      comment = %Comment{commentable: post, content: "Great post!"}
      |> Comment.changeset(%{})
      |> Repo.insert!()

  Load the polymorphic association:

      comment = Repo.get!(Comment, 1)
      |> PolyEcto.load_polymorphic(:commentable)

  Batch preload multiple records:

      comments = Repo.all(Comment)
      |> PolyEcto.preload_polymorphic(:commentable)

  ## Usage: Polymorphic Has Many

  Define a schema with a polymorphic has_many:

      defmodule Post do
        use Ecto.Schema
        import PolyEcto

        schema "posts" do
          field :title, :string
          polymorphic_has_many :comments, Comment, as: :commentable
          timestamps()
        end
      end

  Query associated records:

      post = Repo.get!(Post, 1)
      comments = PolyEcto.polymorphic_assoc(post, :comments)
      |> Repo.all()

  Preload associations:

      post = Repo.get!(Post, 1)
      |> PolyEcto.preload_polymorphic_assoc(:comments)

  ## Migration

  Create a migration for polymorphic associations:

      create table(:comments) do
        add :commentable_table, :string, null: false
        add :commentable_id, :string, null: false
        add :content, :text
        timestamps()
      end

      create index(:comments, [:commentable_table, :commentable_id])
  """

  @doc """
  Imports PolyEcto macros into the current module.

  ## Example

      defmodule MySchema do
        use Ecto.Schema
        use PolyEcto

        schema "my_table" do
          polymorphic_belongs_to :parent
        end
      end
  """
  defmacro __using__(_opts) do
    quote do
      import PolyEcto,
        only: [
          polymorphic_belongs_to: 1,
          polymorphic_belongs_to: 2,
          polymorphic_has_many: 3
        ]
    end
  end

  @doc """
  Defines a polymorphic belongs_to association.

  Generates three fields:
  - `{name}_table` - String field storing the table name
  - `{name}_id` - String field storing the entity ID
  - `{name}` - Virtual field for the loaded entity

  ## Options

  - `:table_field` - Custom name for the table field (default: `{name}_table`)
  - `:id_field` - Custom name for the id field (default: `{name}_id`)

  ## Examples

      schema "comments" do
        polymorphic_belongs_to :commentable
        field :content, :string
      end

      # With custom field names
      schema "tags" do
        polymorphic_belongs_to :taggable,
          table_field: :entity_table,
          id_field: :entity_id
      end
  """
  defmacro polymorphic_belongs_to(name, opts \\ []) do
    table_field = opts[:table_field] || :"#{name}_table"
    id_field = opts[:id_field] || :"#{name}_id"

    quote do
      field(unquote(table_field), :string)
      field(unquote(id_field), :string)
      field(unquote(name), :any, virtual: true)

      def __polyecto_belongs_to__(unquote(name)) do
        %{
          type: :belongs_to,
          table_field: unquote(table_field),
          id_field: unquote(id_field)
        }
      end
    end
  end

  @doc """
  Defines a polymorphic has_many association.

  Generates one field:
  - `{name}` - Virtual array field for loaded associations

  ## Options

  - `:as` - Required. The name of the polymorphic association in the target schema

  ## Examples

      schema "posts" do
        field :title, :string
        polymorphic_has_many :comments, Comment, as: :commentable
      end
  """
  defmacro polymorphic_has_many(name, queryable, opts) do
    as = Keyword.fetch!(opts, :as)

    quote do
      field(unquote(name), {:array, :any}, virtual: true)

      def __polyecto_has_many__(unquote(name)) do
        %{
          type: :has_many,
          queryable: unquote(queryable),
          as: unquote(as)
        }
      end
    end
  end

  @doc false
  def config do
    Application.get_env(:polyecto, :config) ||
      raise """
      PolyEcto config not set. Add to config.exs:

          config :polyecto, :config, YourConfigModule

      Your config module must implement the PolyEcto.Config behavior.
      """
  end

  # Delegate to implementation modules

  @doc """
  Casts a polymorphic belongs_to association in a changeset.

  When a struct is assigned to the polymorphic virtual field, this function
  extracts the table name and ID, then stores them in the appropriate fields.

  ## Examples

      comment
      |> cast(attrs, [:content])
      |> PolyEcto.cast_polymorphic(:commentable)
  """
  @spec cast_polymorphic(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  defdelegate cast_polymorphic(changeset, field), to: PolyEcto.BelongsTo

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
  defdelegate load_polymorphic(record, field), to: PolyEcto.BelongsTo

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
  defdelegate preload_polymorphic(records, field), to: PolyEcto.BelongsTo

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
  defdelegate polymorphic_assoc(struct, field), to: PolyEcto.HasMany

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
  defdelegate preload_polymorphic_assoc(records, field), to: PolyEcto.HasMany
end
