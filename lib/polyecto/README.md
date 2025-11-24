# PolyEcto - Polymorphic Associations for Ecto

A library for polymorphic associations in Ecto. Provides clean "belongs to any" and "has many polymorphic" relationships with efficient batch loading.

## Features

- Generic design works with any schema
- Familiar Ecto-style API
- Batch loading prevents N+1 queries
- Table-based storage (stable across module renames)
- Full typespecs and compile-time checks
- Zero external dependencies

## Installation

```elixir
def deps do
  [
    {:polyecto, "~> 0.1.0"}
  ]
end
```

## Configuration

Create a configuration module:

```elixir
defmodule MyApp.PolyEctoConfig do
  @behaviour PolyEcto.Config

  @registry %{
    "posts" => MyApp.Post,
    "comments" => MyApp.Comment,
    "users" => MyApp.User
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

Configure in `config/config.exs`:

```elixir
config :polyecto, :config, MyApp.PolyEctoConfig
```

## Polymorphic Belongs To

Define a schema that belongs to multiple entity types:

```elixir
defmodule Comment do
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
    |> validate_required([:content, :commentable_table, :commentable_id])
  end
end
```

The `polymorphic_belongs_to` macro generates:
- `commentable_table` - stores the table name
- `commentable_id` - stores the entity ID
- `commentable` - virtual field for the loaded entity

### Migration

```elixir
create table(:comments) do
  add :commentable_table, :string, null: false
  add :commentable_id, :string, null: false
  add :content, :text
  timestamps()
end

create index(:comments, [:commentable_table, :commentable_id])
```

### Creating Records

```elixir
post = Repo.get!(Post, 1)
comment = %Comment{commentable: post, content: "Great post"}
|> Comment.changeset(%{})
|> Repo.insert!()
```

### Loading Associations

```elixir
# Single record
comment = Repo.get!(Comment, 1)
|> PolyEcto.load_polymorphic(:commentable)

# Batch preload (prevents N+1)
comments = Repo.all(Comment)
|> PolyEcto.preload_polymorphic(:commentable)
```

## Polymorphic Has Many

Define schemas that can have polymorphic children:

```elixir
defmodule Post do
  use Ecto.Schema
  import PolyEcto

  schema "posts" do
    field :title, :string
    polymorphic_has_many :comments, Comment, as: :commentable
    timestamps()
  end
end
```

### Querying Associations

```elixir
post = Repo.get!(Post, 1)

# Build a query
query = PolyEcto.polymorphic_assoc(post, :comments)
comments = Repo.all(query)

# Compose with additional filters
recent = PolyEcto.polymorphic_assoc(post, :comments)
|> where([c], c.inserted_at > ago(7, "day"))
|> Repo.all()
```

### Preloading Associations

```elixir
# Single record
post = Repo.get!(Post, 1)
|> PolyEcto.preload_polymorphic_assoc(:comments)

# Multiple records (batch loaded)
posts = Repo.all(Post)
|> PolyEcto.preload_polymorphic_assoc(:comments)
```

## Custom Field Names

Customize the generated field names:

```elixir
schema "notifications" do
  polymorphic_belongs_to :notifiable,
    table_field: :target_table,
    id_field: :target_id

  field :message, :string
end
```

This generates `target_table` and `target_id` instead of `notifiable_table` and `notifiable_id`.

## Performance

### Batch Preloading

PolyEcto groups records by table and executes a single query per table:

```elixir
# 100 comments: 60 on posts, 40 on cards
comments = Repo.all(Comment)  # 1 query
|> PolyEcto.preload_polymorphic(:commentable)  # 2 queries (posts, cards)
# Total: 3 queries instead of 101
```

### Indexing

Always create a composite index on polymorphic fields:

```elixir
create index(:comments, [:commentable_table, :commentable_id])
```

## Query Composition

Polymorphic queries return standard `Ecto.Query` structs:

```elixir
base = PolyEcto.polymorphic_assoc(post, :comments)

# Add filters
recent = base |> where([c], c.inserted_at > ago(7, "day"))

# Add ordering
sorted = base |> order_by([c], desc: c.inserted_at)

# Combine
filtered = base
|> where([c], c.inserted_at > ago(7, "day"))
|> order_by([c], desc: c.inserted_at)
|> limit(10)
|> Repo.all()
```

## Advanced Usage

### Nested Polymorphic Associations

You can have polymorphic associations on both sides:

```elixir
defmodule ActivityLog do
  use Ecto.Schema
  import PolyEcto

  schema "activity_logs" do
    polymorphic_belongs_to :target
    field :action, :string
    timestamps()
  end
end

defmodule Post do
  use Ecto.Schema
  import PolyEcto

  schema "posts" do
    field :title, :string
    polymorphic_has_many :activity_logs, ActivityLog, as: :target
    polymorphic_has_many :comments, Comment, as: :commentable
  end
end

# Load multiple associations
post = Repo.get!(Post, 1)
|> PolyEcto.preload_polymorphic_assoc(:activity_logs)
|> PolyEcto.preload_polymorphic_assoc(:comments)
```

Note: Each ActivityLog belongs to one entity (one-to-many). For many-to-many relationships, see the Limitations section.

### Filtering by Entity Type

```elixir
# Get only comments on posts
post_comments = from(c in Comment, where: c.commentable_table == "posts")
|> Repo.all()
|> PolyEcto.preload_polymorphic(:commentable)

# Get comments on multiple types
entity_comments = from(c in Comment, 
  where: c.commentable_table in ["posts", "articles"])
|> Repo.all()
```

### Counting Associations

Get counts without loading records:

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
```

### Aggregating Across Types

```elixir
# Comment counts by entity type
from(c in Comment,
  group_by: c.commentable_table,
  select: {c.commentable_table, count(c.id)}
)
|> Repo.all()
# Returns: [{"posts", 45}, {"cards", 23}]

# Recent comments across all types
from(c in Comment,
  where: c.inserted_at > ago(7, "day"),
  order_by: [desc: c.inserted_at]
)
|> Repo.all()
|> PolyEcto.preload_polymorphic(:commentable)
```

## Best Practices

### Use Composite Indexes

```elixir
# Correct
create index(:comments, [:commentable_table, :commentable_id])

# Incorrect (less efficient)
create index(:comments, [:commentable_table])
create index(:comments, [:commentable_id])
```

### Prefer Batch Preloading

```elixir
# Correct
comments = Repo.all(Comment)
|> PolyEcto.preload_polymorphic(:commentable)

# Incorrect (N+1 queries)
comments = Repo.all(Comment)
|> Enum.map(&PolyEcto.load_polymorphic(&1, :commentable))
```

### Validate Polymorphic Fields

```elixir
def changeset(comment, attrs) do
  comment
  |> cast(attrs, [:content])
  |> PolyEcto.cast_polymorphic(:commentable)
  |> validate_required([:commentable_table, :commentable_id])
  |> validate_polymorphic_table(:commentable_table)
end

defp validate_polymorphic_table(changeset, field) do
  validate_change(changeset, field, fn _, table ->
    if table in ["posts", "cards", "articles"] do
      []
    else
      [{field, "invalid entity type"}]
    end
  end)
end
```

### Handle Deleted Entities

```elixir
comment = Repo.get!(Comment, id)
|> PolyEcto.load_polymorphic(:commentable)

case comment.commentable do
  nil -> 
    Logger.warning("Entity not found for comment #{id}")
    render_orphaned_comment(comment)
  entity -> 
    render_comment_with_entity(comment, entity)
end
```

## Common Pitfalls

### Missing cast_polymorphic

```elixir
# Incorrect - fields won't be set
def changeset(comment, attrs) do
  comment
  |> cast(attrs, [:content])
end

# Correct
def changeset(comment, attrs) do
  comment
  |> cast(attrs, [:content])
  |> PolyEcto.cast_polymorphic(:commentable)
end
```

### Missing Index

```elixir
# Incorrect - queries will be slow
create table(:comments) do
  add :commentable_table, :string
  add :commentable_id, :string
end

# Correct
create table(:comments) do
  add :commentable_table, :string
  add :commentable_id, :string
end
create index(:comments, [:commentable_table, :commentable_id])
```

### Individual Loads in Loops

```elixir
# Incorrect - N+1 queries
Enum.each(comments, fn comment ->
  comment = PolyEcto.load_polymorphic(comment, :commentable)
  display(comment)
end)

# Correct - batch preload
comments = PolyEcto.preload_polymorphic(comments, :commentable)
Enum.each(comments, &display/1)
```

### Validating Virtual Field

```elixir
# Incorrect
def changeset(comment, attrs) do
  comment
  |> cast(attrs, [:content])
  |> PolyEcto.cast_polymorphic(:commentable)
  |> validate_required([:commentable])  # Virtual field
end

# Correct
def changeset(comment, attrs) do
  comment
  |> cast(attrs, [:content])
  |> PolyEcto.cast_polymorphic(:commentable)
  |> validate_required([:commentable_table, :commentable_id])
end
```

## Migration Patterns

### Basic Polymorphic Table

```elixir
create table(:comments) do
  add :commentable_table, :string, null: false
  add :commentable_id, :string, null: false
  add :content, :text
  timestamps()
end

create index(:comments, [:commentable_table, :commentable_id])
```

### Multiple Polymorphic Associations

```elixir
create table(:activities) do
  add :actor_table, :string, null: false
  add :actor_id, :string, null: false
  add :target_table, :string, null: false
  add :target_id, :string, null: false
  add :action_type, :string
  timestamps()
end

create index(:activities, [:actor_table, :actor_id])
create index(:activities, [:target_table, :target_id])
```

### Adding Polymorphic Fields to Existing Table

```elixir
alter table(:comments) do
  add :commentable_table, :string
  add :commentable_id, :string
end

# Backfill existing data
execute """
UPDATE comments
SET commentable_table = 'posts',
    commentable_id = post_id::text
WHERE post_id IS NOT NULL
"""

# Make required after backfill
alter table(:comments) do
  modify :commentable_table, :string, null: false
  modify :commentable_id, :string, null: false
end

alter table(:comments) do
  remove :post_id
end

create index(:comments, [:commentable_table, :commentable_id])
```

## Limitations

### Many-to-Many Polymorphic Relationships

PolyEcto supports only one-to-many polymorphic relationships:

- Supported: A Comment belongs to one Post/Article (polymorphic belongs_to)
- Supported: A Post has many Comments (polymorphic has_many)
- Not supported: A Tag belongs to many Posts/Articles (many-to-many)

For many-to-many polymorphic relationships, use a join table:

```elixir
# This does not work with PolyEcto
defmodule Tag do
  schema "tags" do
    polymorphic_belongs_to :taggable  # Can only tag ONE entity
    field :name, :string
  end
end

# Use a join table instead
defmodule Tag do
  schema "tags" do
    field :name, :string
    has_many :taggings, Tagging
  end
end

defmodule Tagging do
  schema "taggings" do
    belongs_to :tag, Tag
    polymorphic_belongs_to :taggable  # Each tagging links one tag to one entity
  end
end
```

### Appropriate Use Cases

**When to use PolyEcto:**
- Comments on multiple entity types
- Activity logs for any entity
- Notifications about different entities
- File attachments to various records

**When not to use PolyEcto:**
- Tagging systems (need many-to-many)
- Categories shared by multiple entities
- Any scenario requiring many-to-many relationships

## Troubleshooting

### Config Not Set Error

```
PolyEcto config not set. Add to config.exs:
    config :polyecto, :config, YourConfigModule
```

Solution: Add the config line to `config/config.exs` and restart.

### Unknown Table Error

If associations load as `nil`, the table may not be in your registry.

Solution: Add the table-to-module mapping:

```elixir
@registry %{
  "posts" => MyApp.Post,
  "missing_table" => MyApp.MissingModule
}
```

### Slow Queries

Check your indexes:

```elixir
create index(:comments, [:commentable_table, :commentable_id])
```

### N+1 Queries

Use batch preloading:

```elixir
# Correct
comments = Repo.all(Comment)
|> PolyEcto.preload_polymorphic(:commentable)
```

## Design Decisions

### Table Names vs Module Names

PolyEcto uses table names instead of module names for stability:
- Module renames don't break existing data
- Works across different namespaces
- Easy to filter by table in SQL
- Clear reference to the entity

### Manual Registry

The explicit registry provides:
- No magic or runtime discovery issues
- Clear, debuggable mapping
- Flexibility to override mappings
- Simple to understand

### No Referential Integrity

Databases cannot enforce foreign keys to multiple tables. This is a fundamental limitation of polymorphic associations, not specific to PolyEcto. The same approach is used by:
- Ruby on Rails polymorphic associations
- Laravel polymorphic relationships
- Django GenericForeignKey

Mitigation: Use application-level validation and handle deleted entities gracefully.

### String IDs

Polymorphic ID fields use strings for universality:
- Handles UUIDs, integers, and custom IDs
- Single column type simplifies implementation
- Values are cast to proper type when loading

## API Reference

### Macros

**`polymorphic_belongs_to(name, opts \\ [])`**

Defines a polymorphic belongs_to association.

Options:
- `:table_field` - Custom name for the table field
- `:id_field` - Custom name for the ID field

**`polymorphic_has_many(name, queryable, opts)`**

Defines a polymorphic has_many association.

Options:
- `:as` - Required. Name of the polymorphic association in the target schema

### Functions

**`cast_polymorphic(changeset, field)`**

Casts a polymorphic association in a changeset.

**`load_polymorphic(record, field)`**

Loads a polymorphic association for a single record.

**`preload_polymorphic(records, field)`**

Batch preloads polymorphic belongs_to associations.

**`polymorphic_assoc(struct, field)`**

Builds an Ecto.Query for polymorphic has_many associations.

**`preload_polymorphic_assoc(records, field)`**

Batch preloads polymorphic has_many associations.

### Behaviors

**`PolyEcto.Config`**

Callbacks:
- `repo/0` - Returns the Ecto.Repo module
- `get_schema/1` - Returns schema module for a table name
- `get_table/1` - Returns table name for a schema module

## Testing

The package includes a comprehensive test suite with 61 tests covering:
- Polymorphic belongs_to functionality
- Polymorphic has_many functionality
- Batch loading and N+1 prevention
- Edge cases (nil values, missing entities)
- Integration scenarios
- Performance with large datasets

Run tests:

```bash
mix test
```
