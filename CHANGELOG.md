# Changelog

## [0.1.0] - 2025-11-24

### Added

- Initial release of PolyEcto
- Polymorphic `belongs_to` associations with `polymorphic_belongs_to/2` macro
- Polymorphic `has_many` associations with `polymorphic_has_many/3` macro
- Configuration behavior (`PolyEcto.Config`) for table-to-schema mapping
- Batch preloading support to prevent N+1 queries
  - `preload_polymorphic/2` for belongs_to associations
  - `preload_polymorphic_assoc/2` for has_many associations
- Single record loading with `load_polymorphic/2`
- Query building with `polymorphic_assoc/2` for composable queries
- Changeset casting with `cast_polymorphic/2`
- Table-based polymorphic field storage (stable across module renames)
- Custom field naming support via `:table_field` and `:id_field` options
- Comprehensive documentation with 1000+ lines of examples and guides
- Full test suite with 61 tests covering:
  - Polymorphic belongs_to functionality
  - Polymorphic has_many functionality
  - Batch loading and N+1 prevention
  - Edge cases (nil values, missing entities, empty associations)
  - Integration scenarios
  - Performance tests with large datasets

### Features

- **Generic Design**: Works with any schema, no hardcoded relationships
- **Ecto-Native API**: Familiar patterns for Ecto users
- **Efficient Queries**: Intelligent batch loading groups records by table
- **Type Safety**: Full typespecs and compile-time checks
- **Zero Extra Dependencies**: Pure Ecto implementation
- **Flexible Configuration**: Per-environment config support

### Documentation

- Quick start guide in README.md
- Comprehensive guide in lib/polyecto/README.md covering:
  - Configuration setup
  - Usage examples for belongs_to and has_many
  - Migration patterns
  - Query composition
  - Performance optimization
  - Best practices
  - Common pitfalls and troubleshooting
  - Advanced usage patterns
  - **Limitations section** clearly explaining that only one-to-many relationships are supported (not many-to-many)
- CI/CD setup with GitHub Actions
- Publishing guide for Hex.pm
