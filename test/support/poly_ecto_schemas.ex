defmodule PolyEctoTest.TestCard do
  @moduledoc """
  Test schema for polymorphic association testing.
  """
  use Ecto.Schema
  import PolyEcto

  @primary_key {:id, :string, autogenerate: false}
  schema "test_cards" do
    field(:text, :string)
    polymorphic_has_many(:comments, PolyEctoTest.TestComment, as: :commentable)
    timestamps()
  end
end

defmodule PolyEctoTest.TestComment do
  @moduledoc """
  Test schema with polymorphic belongs_to for testing.
  """
  use Ecto.Schema
  import PolyEcto

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "test_comments" do
    polymorphic_belongs_to(:commentable)
    field(:content, :string)
    timestamps()
  end

  def changeset(comment, attrs) do
    import Ecto.Changeset

    changeset =
      comment
      |> cast(attrs, [:content])

    # Handle polymorphic association if present
    case Map.get(attrs, :commentable) do
      nil ->
        changeset

      commentable ->
        changeset
        |> put_change(:commentable, commentable)
        |> PolyEcto.cast_polymorphic(:commentable)
    end
  end
end

defmodule PolyEctoTest.TestPost do
  @moduledoc """
  Test schema for polymorphic association testing.
  """
  use Ecto.Schema
  import PolyEcto

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "test_posts" do
    field(:title, :string)
    polymorphic_has_many(:comments, PolyEctoTest.TestComment, as: :commentable)
    timestamps()
  end
end
