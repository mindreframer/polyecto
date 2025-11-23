defmodule PolyEcto.TestRepo.Migrations.CreateTestSchemas do
  use Ecto.Migration

  def change do
    # Create test_posts table
    create table(:test_posts, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:title, :string)

      timestamps()
    end

    # Create test_cards table
    create table(:test_cards, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:text, :string)

      timestamps()
    end

    # Create test_comments table with polymorphic association
    create table(:test_comments, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:commentable_table, :string, null: false)
      add(:commentable_id, :string, null: false)
      add(:content, :string)

      timestamps()
    end

    # Create composite index for polymorphic lookups
    create(index(:test_comments, [:commentable_table, :commentable_id]))
  end
end
