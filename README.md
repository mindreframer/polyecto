# PolyEcto

A generic, configurable library for polymorphic associations in Ecto schemas. PolyEcto provides a clean, efficient way to create "belongs to any" and "has many polymorphic" relationships without sacrificing Ecto's familiar patterns.

See the [detailed documentation](lib/polyecto/README.md) for comprehensive usage examples and API reference.

## Features

- **Generic & Reusable**: Zero hardcoded relationship types - works with any schema
- **Ecto-Native API**: Feels like standard Ecto associations
- **Efficient Queries**: Batch loading with no N+1 queries
- **Table-Based Storage**: Uses stable table names (not module names)
- **Type Safe**: Full typespecs and compile-time checks
- **Zero Dependencies**: Pure Ecto, no external libraries

## Installation

Add `polyecto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:polyecto, "~> 0.1.0"},
    {:ecto, "~> 3.10"}
  ]
end
```

## Quick Start

1. Create a config module:

```elixir
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
```

2. Configure it in `config/config.exs`:

```elixir
config :polyecto, :config, MyApp.PolyEctoConfig
```

3. Use in your schemas:

```elixir
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
  end
end
```

## Documentation

For detailed documentation including:
- Complete usage examples
- Migration patterns
- Best practices
- Performance considerations
- Troubleshooting guide

See the [comprehensive README](lib/polyecto/README.md).

## License

MIT

