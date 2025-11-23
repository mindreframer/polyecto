# PolyEcto - Polymorphic Associations for Ecto

A generic, configurable library for polymorphic associations in Ecto schemas. PolyEcto provides a clean, efficient way to create "belongs to any" and "has many polymorphic" relationships without sacrificing Ecto's familiar patterns.

## Features

- **Generic & Reusable**: Zero hardcoded relationship types - works with any schema
- **Ecto-Native API**: Feels like standard Ecto associations
- **Efficient Queries**: Batch loading with no N+1 queries
- **Table-Based Storage**: Uses stable table names (not module names)
- **Type Safe**: Full typespecs and compile-time checks
- **Zero Dependencies**: Pure Ecto, no external libraries

## Installation

1. Copy the `lib/polyecto/` directory to your project
2. Create a configuration module (see Configuration below)
3. Add the config to your `config/config.exs`

## Configuration

Create a module that implements the `PolyEcto.Config` behavior:

```elixir
defmodule MyApp.PolyEctoConfig do
  @behaviour PolyEcto.Config

  @registry %{
    "posts" => MyApp.Blog.Post,
    "comments" => MyApp.Blog.Comment,
    "users" => MyApp.Accounts.User,
    "base_cards" => MyApp.Cards.BaseCard
  }

  @reverse_registry Map.new(@registry, fn {k, v} -> {v, k} end)

  @impl true
  def repo, do: MyApp.Repo

  @impl true
  def get_schema(table_name), do: Map.get(@registry, table_name)

  @impl true
  def get_table(schema_module), do: Map.get(@reverse_registry, schema_module)
end
```

Then configure it in `config/config.exs`:

```elixir
config :polyecto, :config, MyApp.PolyEctoConfig
```

## Usage: Polymorphic Belongs To

### Define the Schema

Create a schema that belongs to multiple entity types:

```elixir
defmodule MyApp.Blog.Comment do
  use Ecto.Schema
  import PolyEcto

  schema "comments" do
    polymorphic_belongs_to :commentable
    field :content, :text
    field :user_id, :string

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:content, :user_id])
    |> PolyEcto.cast_polymorphic(:commentable)
    |> validate_required([:content, :commentable_table, :commentable_id])
  end
end
```

This generates three fields:
- `commentable_table` - String field storing the table name
- `commentable_id` - String field storing the entity ID
- `commentable` - Virtual field for the loaded entity

### Create the Migration

```elixir
defmodule MyApp.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :commentable_table, :string, null: false
      add :commentable_id, :string, null: false
      add :content, :text, null: false
      add :user_id, :string

      timestamps()
    end

    # Critical for query performance
    create index(:comments, [:commentable_table, :commentable_id])
  end
end
```

### Create Records

```elixir
# Comment on a post
post = Repo.get!(Post, "post_123")
comment = %Comment{commentable: post, content: "Great post!"}
|> Comment.changeset(%{})
|> Repo.insert!()

# Comment on a card
card = Repo.get!(BaseCard, "card_456")
comment = %Comment{commentable: card, content: "Love this!"}
|> Comment.changeset(%{})
|> Repo.insert!()
```

### Load Associations

```elixir
# Load single record
comment = Repo.get!(Comment, comment_id)
|> PolyEcto.load_polymorphic(:commentable)

comment.commentable # => %Post{...} or %BaseCard{...}

# Batch preload (no N+1 queries)
comments = Repo.all(Comment)
|> PolyEcto.preload_polymorphic(:commentable)

# Groups by table, one query per table type
Enum.each(comments, fn c ->
  IO.inspect(c.commentable)
end)
```

## Usage: Polymorphic Has Many

### Define the Parent Schema

Add polymorphic has_many to schemas that can have comments:

```elixir
defmodule MyApp.Blog.Post do
  use Ecto.Schema
  import PolyEcto

  schema "posts" do
    field :title, :string
    field :body, :text

    polymorphic_has_many :comments, MyApp.Blog.Comment, as: :commentable

    timestamps()
  end
end

defmodule MyApp.Cards.BaseCard do
  use Ecto.Schema
  import PolyEcto

  schema "base_cards" do
    field :text, :string

    polymorphic_has_many :comments, MyApp.Blog.Comment, as: :commentable

    timestamps()
  end
end
```

This generates one virtual field:
- `comments` - Virtual array field for loaded associations

### Query Associations

```elixir
# Build a query
post = Repo.get!(Post, "post_123")
query = PolyEcto.polymorphic_assoc(post, :comments)
comments = Repo.all(query)

# Compose with additional filters
recent_comments =
  PolyEcto.polymorphic_assoc(post, :comments)
  |> where([c], c.inserted_at > ago(7, "day"))
  |> order_by([c], desc: c.inserted_at)
  |> Repo.all()
```

### Preload Associations

```elixir
# Single record
post = Repo.get!(Post, "post_123")
|> PolyEcto.preload_polymorphic_assoc(:comments)

post.comments # => [%Comment{...}, ...]

# Multiple records (batch loaded, no N+1)
posts = Repo.all(Post)
|> PolyEcto.preload_polymorphic_assoc(:comments)

Enum.each(posts, fn post ->
  IO.puts("#{post.title} has #{length(post.comments)} comments")
end)
```

## Custom Field Names

You can customize the generated field names:

```elixir
schema "tags" do
  polymorphic_belongs_to :taggable,
    table_field: :entity_table,
    id_field: :entity_id

  field :name, :string
end
```

This generates:
- `entity_table` instead of `taggable_table`
- `entity_id` instead of `taggable_id`
- `taggable` (virtual field name unchanged)

## Performance

### Batch Preloading

PolyEcto prevents N+1 queries by grouping records by table and executing a single query per table:

```elixir
# Given 100 comments: 60 on posts, 40 on cards
comments = Repo.all(Comment) # 1 query
|> PolyEcto.preload_polymorphic(:commentable) # 2 queries (posts, cards)

# Total: 3 queries instead of 101
```

### Indexing

Always create a composite index on the polymorphic fields:

```elixir
create index(:comments, [:commentable_table, :commentable_id])
```

This enables efficient lookups when querying by parent entity.

## Query Composition

Polymorphic queries return standard `Ecto.Query` structs, so you can compose them:

```elixir
base_query = PolyEcto.polymorphic_assoc(post, :comments)

# Add filters
recent = base_query |> where([c], c.inserted_at > ago(7, "day"))

# Add ordering
sorted = base_query |> order_by([c], desc: c.inserted_at)

# Add limits
top_10 = base_query |> limit(10)

# Combine
top_recent =
  base_query
  |> where([c], c.inserted_at > ago(7, "day"))
  |> order_by([c], desc: c.inserted_at)
  |> limit(10)
  |> Repo.all()
```

## Complete Example

Here's a full example with posts, cards, and comments:

```elixir
# 1. Create config
defmodule MyApp.PolyEctoConfig do
  @behaviour PolyEcto.Config

  @registry %{
    "posts" => MyApp.Post,
    "base_cards" => MyApp.BaseCard
  }

  @reverse_registry Map.new(@registry, fn {k, v} -> {v, k} end)

  @impl true
  def repo, do: MyApp.Repo

  @impl true
  def get_schema(table_name), do: Map.get(@registry, table_name)

  @impl true
  def get_table(schema_module), do: Map.get(@reverse_registry, schema_module)
end

# 2. Configure
# In config/config.exs
config :polyecto, :config, MyApp.PolyEctoConfig

# 3. Define schemas
defmodule MyApp.Comment do
  use Ecto.Schema
  import PolyEcto

  schema "comments" do
    polymorphic_belongs_to :commentable
    field :content, :text
    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:content])
    |> PolyEcto.cast_polymorphic(:commentable)
    |> validate_required([:content])
  end
end

defmodule MyApp.Post do
  use Ecto.Schema
  import PolyEcto

  schema "posts" do
    field :title, :string
    polymorphic_has_many :comments, MyApp.Comment, as: :commentable
    timestamps()
  end
end

defmodule MyApp.BaseCard do
  use Ecto.Schema
  import PolyEcto

  schema "base_cards" do
    field :text, :string
    polymorphic_has_many :comments, MyApp.Comment, as: :commentable
    timestamps()
  end
end

# 4. Use it
post = Repo.get!(Post, 1)
card = Repo.get!(BaseCard, "card_1")

# Create comments
{:ok, comment1} = %Comment{commentable: post, content: "Great!"}
|> Comment.changeset(%{})
|> Repo.insert()

{:ok, comment2} = %Comment{commentable: card, content: "Love it!"}
|> Comment.changeset(%{})
|> Repo.insert()

# Load belongs_to
comment1 = PolyEcto.load_polymorphic(comment1, :commentable)
comment1.commentable # => %Post{...}

# Load has_many
post = PolyEcto.preload_polymorphic_assoc(post, :comments)
post.comments # => [%Comment{...}]

# Query has_many
comments = PolyEcto.polymorphic_assoc(card, :comments)
|> Repo.all()
```

## Advanced Usage Patterns

### Filtering Polymorphic Results

You can filter polymorphic associations by type before loading:

```elixir
# Get only comments on posts (not cards)
post_comments =
  from(c in Comment, where: c.commentable_table == "posts")
  |> Repo.all()
  |> PolyEcto.preload_polymorphic(:commentable)

# Get comments on specific entity types
entity_comments =
  from(c in Comment, where: c.commentable_table in ["posts", "articles"])
  |> Repo.all()
```

### Conditional Preloading

Load polymorphic associations only when needed:

```elixir
def get_comment(id, preload: preload_opts) do
  comment = Repo.get!(Comment, id)

  if Keyword.get(preload_opts, :commentable, false) do
    PolyEcto.load_polymorphic(comment, :commentable)
  else
    comment
  end
end

# Usage
comment = get_comment(123, preload: [commentable: true])
```

### Nested Polymorphic Associations

You can have polymorphic associations on both sides:

```elixir
# Tags can tag any entity
defmodule Tag do
  use Ecto.Schema
  import PolyEcto

  schema "tags" do
    polymorphic_belongs_to :taggable
    field :name, :string
  end
end

# Any entity can have tags
defmodule Post do
  use Ecto.Schema
  import PolyEcto

  schema "posts" do
    field :title, :string
    polymorphic_has_many :tags, Tag, as: :taggable
    polymorphic_has_many :comments, Comment, as: :commentable
  end
end

# Load nested associations
post = Repo.get!(Post, 1)
|> PolyEcto.preload_polymorphic_assoc(:tags)
|> PolyEcto.preload_polymorphic_assoc(:comments)
```

### Counting Polymorphic Associations

Get counts without loading full records:

```elixir
def count_comments(entity) do
  module = entity.__struct__
  table = PolyEcto.config().get_table(module)
  id = Map.get(entity, :id)

  from(c in Comment,
    where: c.commentable_table == ^table,
    where: c.commentable_id == ^to_string(id),
    select: count(c.id)
  )
  |> Repo.one()
end

# Usage
post = Repo.get!(Post, 1)
comment_count = count_comments(post)
```

### Aggregating Across Polymorphic Types

Query across all polymorphic types:

```elixir
# Get comment counts grouped by entity type
from(c in Comment,
  group_by: c.commentable_table,
  select: {c.commentable_table, count(c.id)}
)
|> Repo.all()
# => [{"posts", 45}, {"base_cards", 23}, {"articles", 12}]

# Get recent comments across all types
recent_comments =
  from(c in Comment,
    where: c.inserted_at > ago(7, "day"),
    order_by: [desc: c.inserted_at]
  )
  |> Repo.all()
  |> PolyEcto.preload_polymorphic(:commentable)
```

### Using with Phoenix Contexts

Integrate PolyEcto into Phoenix contexts:

```elixir
defmodule MyApp.Content do
  import Ecto.Query
  alias MyApp.Repo
  alias MyApp.Content.Comment

  def list_comments_for(entity) do
    PolyEcto.polymorphic_assoc(entity, :comments)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def create_comment(entity, attrs) do
    %Comment{commentable: entity}
    |> Comment.changeset(attrs)
    |> Repo.insert()
  end

  def get_comment_with_parent(id) do
    Repo.get!(Comment, id)
    |> PolyEcto.load_polymorphic(:commentable)
  end
end
```

## Best Practices

### 1. Always Use Composite Indexes

For optimal performance, create composite indexes on polymorphic fields:

```elixir
# Good: Composite index
create index(:comments, [:commentable_table, :commentable_id])

# Bad: Separate indexes (less efficient)
create index(:comments, [:commentable_table])
create index(:comments, [:commentable_id])
```

### 2. Use Batch Preloading

Always prefer batch preloading over individual loads:

```elixir
# ✅ Good: Single query per table type
comments = Repo.all(Comment)
|> PolyEcto.preload_polymorphic(:commentable)

# ❌ Bad: N+1 queries
comments = Repo.all(Comment)
|> Enum.map(&PolyEcto.load_polymorphic(&1, :commentable))
```

### 3. Validate Polymorphic Fields

Add validation in your changesets:

```elixir
def changeset(comment, attrs) do
  comment
  |> cast(attrs, [:content])
  |> PolyEcto.cast_polymorphic(:commentable)
  |> validate_required([:content, :commentable_table, :commentable_id])
  |> validate_polymorphic_table(:commentable_table)
end

defp validate_polymorphic_table(changeset, field) do
  validate_change(changeset, field, fn _, table ->
    valid_tables = ["posts", "base_cards", "articles"]

    if table in valid_tables do
      []
    else
      [{field, "must be one of: #{Enum.join(valid_tables, ", ")}"}]
    end
  end)
end
```

### 4. Handle Deleted Entities Gracefully

Check for nil when loading polymorphic associations:

```elixir
comment = Repo.get!(Comment, id)
|> PolyEcto.load_polymorphic(:commentable)

case comment.commentable do
  nil ->
    # Entity was deleted, handle gracefully
    Logger.warn("Commentable entity not found for comment #{id}")
    render_orphaned_comment(comment)

  entity ->
    render_comment_with_entity(comment, entity)
end
```

### 5. Keep Registry Updated

When adding new schemas, update your registry:

```elixir
# Add to your PolyEctoConfig module
@registry %{
  "posts" => MyApp.Post,
  "base_cards" => MyApp.BaseCard,
  "articles" => MyApp.Article  # Don't forget new schemas!
}
```

### 6. Use Descriptive Field Names

For clarity, use descriptive names when you have multiple polymorphic associations:

```elixir
schema "activities" do
  polymorphic_belongs_to :actor  # Who performed the action
  polymorphic_belongs_to :target # What was acted upon
  field :action_type, :string
end
```

## Common Pitfalls

### Pitfall 1: Forgetting to Cast Polymorphic Fields

```elixir
# ❌ Bad: Polymorphic fields not set
def changeset(comment, attrs) do
  comment
  |> cast(attrs, [:content])
  # Missing: |> PolyEcto.cast_polymorphic(:commentable)
end

# ✅ Good: Always cast polymorphic fields
def changeset(comment, attrs) do
  comment
  |> cast(attrs, [:content])
  |> PolyEcto.cast_polymorphic(:commentable)
end
```

### Pitfall 2: Missing Composite Index

```elixir
# ❌ Bad: No index on polymorphic fields
create table(:comments) do
  add :commentable_table, :string
  add :commentable_id, :string
  add :content, :text
end
# Queries will be slow!

# ✅ Good: Composite index for performance
create table(:comments) do
  add :commentable_table, :string
  add :commentable_id, :string
  add :content, :text
end
create index(:comments, [:commentable_table, :commentable_id])
```

### Pitfall 3: Using load_polymorphic in Loops

```elixir
# ❌ Bad: N+1 queries
comments = Repo.all(Comment)
Enum.each(comments, fn comment ->
  comment = PolyEcto.load_polymorphic(comment, :commentable)
  display(comment)
end)

# ✅ Good: Batch preload
comments = Repo.all(Comment)
|> PolyEcto.preload_polymorphic(:commentable)

Enum.each(comments, fn comment ->
  display(comment)
end)
```

### Pitfall 4: Wrong Config Key

```elixir
# ❌ Bad: Wrong config key
config :polyecto, :configuration, MyApp.PolyEctoConfig

# ✅ Good: Correct config key
config :polyecto, :config, MyApp.PolyEctoConfig
```

### Pitfall 5: Forgetting to Add Tables to Registry

```elixir
# ❌ Bad: New table not in registry
@registry %{
  "posts" => MyApp.Post
  # Forgot to add "articles" table!
}

# When loading Article comments, commentable will be nil

# ✅ Good: All tables in registry
@registry %{
  "posts" => MyApp.Post,
  "articles" => MyApp.Article
}
```

### Pitfall 6: Incorrect Field Validation

```elixir
# ❌ Bad: Validating virtual field
def changeset(comment, attrs) do
  comment
  |> cast(attrs, [:content])
  |> PolyEcto.cast_polymorphic(:commentable)
  |> validate_required([:commentable])  # Virtual field!
end

# ✅ Good: Validate actual database fields
def changeset(comment, attrs) do
  comment
  |> cast(attrs, [:content])
  |> PolyEcto.cast_polymorphic(:commentable)
  |> validate_required([:commentable_table, :commentable_id])
end
```

### Pitfall 7: Hardcoding Table Names

```elixir
# ❌ Bad: Hardcoded table name
from(c in Comment, where: c.commentable_table == "posts")

# ✅ Good: Use config to get table name
table_name = PolyEcto.config().get_table(Post)
from(c in Comment, where: c.commentable_table == ^table_name)
```

## Migration Patterns

### Basic Polymorphic Table

```elixir
defmodule MyApp.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :commentable_table, :string, null: false
      add :commentable_id, :string, null: false
      add :content, :text, null: false
      add :user_id, :string

      timestamps()
    end

    create index(:comments, [:commentable_table, :commentable_id])
    create index(:comments, [:user_id])
  end
end
```

### Multiple Polymorphic Associations

```elixir
defmodule MyApp.Repo.Migrations.CreateActivities do
  use Ecto.Migration

  def change do
    create table(:activities, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Actor: who performed the action
      add :actor_table, :string, null: false
      add :actor_id, :string, null: false

      # Target: what was acted upon
      add :target_table, :string, null: false
      add :target_id, :string, null: false

      add :action_type, :string, null: false

      timestamps()
    end

    # Index for finding activities by actor
    create index(:activities, [:actor_table, :actor_id])

    # Index for finding activities by target
    create index(:activities, [:target_table, :target_id])

    # Index for filtering by action type
    create index(:activities, [:action_type])
  end
end
```

### Adding Polymorphic Fields to Existing Table

```elixir
defmodule MyApp.Repo.Migrations.AddPolymorphicToComments do
  use Ecto.Migration

  def change do
    alter table(:comments) do
      add :commentable_table, :string
      add :commentable_id, :string
    end

    # Backfill existing data if needed
    execute """
    UPDATE comments
    SET commentable_table = 'posts',
        commentable_id = post_id::text
    WHERE post_id IS NOT NULL
    """

    # Make fields required after backfill
    alter table(:comments) do
      modify :commentable_table, :string, null: false
      modify :commentable_id, :string, null: false
    end

    # Remove old foreign key column
    alter table(:comments) do
      remove :post_id
    end

    create index(:comments, [:commentable_table, :commentable_id])
  end
end
```

## Troubleshooting

### Config not set error

```
PolyEcto config not set. Add to config.exs:
    config :polyecto, :config, YourConfigModule
```

**Solution**: Add the config line to `config/config.exs` and restart your application.

### Unknown table error

If you see `nil` when loading associations, the table might not be in your registry.

**Solution**: Add the table → module mapping to your config's `@registry`:

```elixir
@registry %{
  "posts" => MyApp.Post,
  "missing_table" => MyApp.MissingModule  # Add this
}
```

### Slow queries

If queries are slow, check your indexes:

```elixir
# Required index for performance
create index(:comments, [:commentable_table, :commentable_id])
```

### N+1 queries

Use batch preloading instead of individual loads:

```elixir
# Bad: N+1 queries
comments = Repo.all(Comment)
Enum.map(comments, fn c ->
  PolyEcto.load_polymorphic(c, :commentable)
end)

# Good: Batch load
comments = Repo.all(Comment)
|> PolyEcto.preload_polymorphic(:commentable)
```

### Virtual field is nil after insert

The virtual field is not automatically loaded after insert:

```elixir
# Virtual field is nil after insert
{:ok, comment} = %Comment{commentable: post}
|> Comment.changeset(%{content: "Great!"})
|> Repo.insert()

comment.commentable # => nil (virtual field not persisted)

# Solution: Reload if needed
comment = PolyEcto.load_polymorphic(comment, :commentable)
comment.commentable # => %Post{...}
```

## Design Decisions

### Why table names instead of module names?

- **Stable**: Module renames don't break existing data
- **Portable**: Works across different namespaces
- **Queryable**: Easy to filter by table in SQL
- **Clear**: Obvious what entity it references

### Why manual registry?

- **Explicit**: No magic, clear mapping
- **Flexible**: Override table → module mapping as needed
- **Safe**: No runtime discovery issues
- **Simple**: Easy to understand and debug

### Why no referential integrity?

Databases cannot enforce foreign keys to multiple tables. This is a fundamental limitation, not a PolyEcto issue. This is the same approach used by:
- Ruby on Rails polymorphic associations
- Laravel polymorphic relationships
- Django GenericForeignKey

**Mitigation**: Use application-level validation and be careful when deleting entities that may have polymorphic references.

### Why string IDs?

- **Universal**: Handles UUIDs, custom strings, and numeric IDs
- **Simple**: Single column type
- **Flexible**: Cast to proper type when loading

## API Reference

### Macros

- `polymorphic_belongs_to(name, opts \\ [])` - Define polymorphic belongs_to
- `polymorphic_has_many(name, queryable, as: field)` - Define polymorphic has_many

### Functions

- `cast_polymorphic(changeset, field)` - Cast polymorphic association in changeset
- `load_polymorphic(record, field)` - Load association for single record
- `preload_polymorphic(records, field)` - Batch load belongs_to associations
- `polymorphic_assoc(struct, field)` - Build query for has_many associations
- `preload_polymorphic_assoc(records, field)` - Batch load has_many associations

### Behaviors

- `PolyEcto.Config` - Implement this for configuration

## Module Structure

```
lib/polyecto/
├── polyecto.ex      - Main module with macros and public API
├── belongs_to.ex    - Polymorphic belongs_to implementation
├── has_many.ex      - Polymorphic has_many implementation
├── config.ex        - Configuration behavior
├── helpers.ex       - Shared utility functions
└── README.md        - This file
```

## Testing

PolyEcto includes comprehensive tests. See:
- `test/polyecto/belongs_to_test.exs`
- `test/polyecto/has_many_test.exs`
- `test/polyecto/integration_test.exs`

## License

MIT

## Contributing

PolyEcto is designed to be generic and reusable. When contributing:
- Keep it generic - no domain-specific logic
- Maintain backward compatibility
- Add tests for new features
- Update documentation

## Future Enhancements

Potential future additions (not currently implemented):
- Polymorphic many-to-many through tables
- Automatic schema registry generation
- Database validation helpers
- Query optimization hints
- Support for polymorphic associations across databases

