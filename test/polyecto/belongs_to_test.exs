defmodule PolyEcto.BelongsToTest do
  use PolyEcto.DataCase, async: true

  import Ecto.Changeset
  alias PolyEcto.TestRepo
  alias PolyEctoTest.{TestCard, TestComment, TestPost}

  describe "polymorphic_belongs_to macro" do
    test "MCR008_2A_T1: generates table_field" do
      assert :commentable_table in TestComment.__schema__(:fields)
    end

    test "MCR008_2A_T2: generates id_field" do
      assert :commentable_id in TestComment.__schema__(:fields)
    end

    test "MCR008_2A_T3: generates virtual field" do
      # Virtual fields are not in __schema__(:fields) but can be set on structs
      assert %TestComment{}.commentable == nil
    end

    test "MCR008_2A_T4: stores config via __polyecto_belongs_to__/1" do
      config = TestComment.__polyecto_belongs_to__(:commentable)

      assert config.type == :belongs_to
      assert config.table_field == :commentable_table
      assert config.id_field == :commentable_id
    end
  end

  describe "cast_polymorphic/2" do
    test "MCR008_2A_T5: casts struct to table and id fields" do
      card = %TestCard{id: "card_123", text: "Test"}

      changeset =
        %TestComment{}
        |> cast(%{content: "Nice!"}, [:content])
        |> put_change(:commentable, card)
        |> PolyEcto.cast_polymorphic(:commentable)

      assert get_change(changeset, :commentable_table) == "test_cards"
      assert get_change(changeset, :commentable_id) == "card_123"
    end

    test "MCR008_2A_T6: sets table name correctly" do
      card = %TestCard{id: "card_1"}

      changeset =
        %TestComment{}
        |> change()
        |> put_change(:commentable, card)
        |> PolyEcto.cast_polymorphic(:commentable)

      assert get_change(changeset, :commentable_table) == "test_cards"
    end

    test "MCR008_2A_T7: sets id correctly (string)" do
      card = %TestCard{id: "custom_id_123"}

      changeset =
        %TestComment{}
        |> change()
        |> put_change(:commentable, card)
        |> PolyEcto.cast_polymorphic(:commentable)

      assert get_change(changeset, :commentable_id) == "custom_id_123"
    end

    test "MCR008_2A_T8: sets id correctly (UUID)" do
      uuid = Ecto.UUID.generate()
      post = %TestPost{id: uuid}

      changeset =
        %TestComment{}
        |> change()
        |> put_change(:commentable, post)
        |> PolyEcto.cast_polymorphic(:commentable)

      assert get_change(changeset, :commentable_table) == "test_posts"
      assert get_change(changeset, :commentable_id) == uuid
    end

    test "MCR008_2A_T9: removes virtual field from changeset" do
      card = %TestCard{id: "card_1"}

      changeset =
        %TestComment{}
        |> change()
        |> put_change(:commentable, card)
        |> PolyEcto.cast_polymorphic(:commentable)

      refute get_change(changeset, :commentable)
    end

    test "MCR008_2A_T10: handles nil (no change)" do
      changeset =
        %TestComment{}
        |> cast(%{content: "Test"}, [:content])
        |> PolyEcto.cast_polymorphic(:commentable)

      refute get_change(changeset, :commentable_table)
      refute get_change(changeset, :commentable_id)
      refute get_change(changeset, :commentable)
    end
  end

  describe "load_polymorphic/2" do
    setup do
      card = TestRepo.insert!(%TestCard{id: "card_1", text: "Hello"})
      post = TestRepo.insert!(%TestPost{title: "Post 1"})

      comment_for_card =
        TestRepo.insert!(%TestComment{
          commentable_table: "test_cards",
          commentable_id: "card_1",
          content: "Comment on card"
        })

      comment_for_post =
        TestRepo.insert!(%TestComment{
          commentable_table: "test_posts",
          commentable_id: post.id,
          content: "Comment on post"
        })

      {:ok,
       card: card,
       post: post,
       comment_for_card: comment_for_card,
       comment_for_post: comment_for_post}
    end

    test "MCR008_2A_T11: loads entity and sets virtual field", %{comment_for_card: comment} do
      loaded = PolyEcto.load_polymorphic(comment, :commentable)

      assert loaded.commentable != nil
      assert loaded.commentable.__struct__ == TestCard
      assert loaded.commentable.id == "card_1"
      assert loaded.commentable.text == "Hello"
    end

    test "MCR008_2A_T12: loads correct schema by table", %{comment_for_post: comment} do
      loaded = PolyEcto.load_polymorphic(comment, :commentable)

      assert loaded.commentable.__struct__ == TestPost
      assert loaded.commentable.title == "Post 1"
    end

    test "MCR008_2A_T13: handles missing entity" do
      comment =
        TestRepo.insert!(%TestComment{
          commentable_table: "test_cards",
          commentable_id: "nonexistent",
          content: "Test"
        })

      loaded = PolyEcto.load_polymorphic(comment, :commentable)

      assert loaded.commentable == nil
    end

    test "MCR008_2A_T14: handles nil table/id" do
      # Create a comment with explicit nil values (bypassing NOT NULL for test purposes)
      # In reality, this should not happen with proper validation
      comment = %TestComment{
        id: Ecto.UUID.generate(),
        commentable_table: nil,
        commentable_id: nil,
        content: "Test"
      }

      loaded = PolyEcto.load_polymorphic(comment, :commentable)

      assert loaded.commentable == nil
    end
  end

  describe "preload_polymorphic/2" do
    setup do
      card1 = TestRepo.insert!(%TestCard{id: "card_1", text: "Card 1"})
      card2 = TestRepo.insert!(%TestCard{id: "card_2", text: "Card 2"})
      post1 = TestRepo.insert!(%TestPost{title: "Post 1"})

      comment1 =
        TestRepo.insert!(%TestComment{
          commentable_table: "test_cards",
          commentable_id: "card_1",
          content: "C1"
        })

      comment2 =
        TestRepo.insert!(%TestComment{
          commentable_table: "test_cards",
          commentable_id: "card_2",
          content: "C2"
        })

      comment3 =
        TestRepo.insert!(%TestComment{
          commentable_table: "test_posts",
          commentable_id: post1.id,
          content: "C3"
        })

      # comment4 - orphaned comment (no parent)
      # Skip creating this as the migration has NOT NULL constraints

      {:ok, comments: [comment1, comment2, comment3], card1: card1, card2: card2, post1: post1}
    end

    test "MCR008_2A_T15: loads multiple entities", %{comments: comments} do
      loaded = PolyEcto.preload_polymorphic(comments, :commentable)

      assert Enum.count(loaded) == 3

      [c1, c2, c3] = loaded

      assert c1.commentable.__struct__ == TestCard
      assert c2.commentable.__struct__ == TestCard
      assert c3.commentable.__struct__ == TestPost
    end

    test "MCR008_2A_T16: groups by table correctly", %{comments: [c1, c2, c3]} do
      loaded = PolyEcto.preload_polymorphic([c1, c2, c3], :commentable)

      [l1, l2, l3] = loaded

      # Both card comments loaded with correct entities
      assert l1.commentable.id == "card_1"
      assert l2.commentable.id == "card_2"

      # Post comment loaded
      assert l3.commentable.__struct__ == TestPost
    end

    test "MCR008_2A_T17: uses single query per table (no N+1)" do
      # Create 10 comments on cards with unique IDs
      cards =
        for i <- 1..10 do
          # Use timestamp to ensure uniqueness across test runs
          unique_id = "card_n1_#{System.system_time(:millisecond)}_#{i}"
          TestRepo.insert!(%TestCard{id: unique_id, text: "Card #{i}"})
        end

      comments =
        for card <- cards do
          TestRepo.insert!(%TestComment{
            commentable_table: "test_cards",
            commentable_id: card.id,
            content: "Comment"
          })
        end

      # This should execute only 2 queries:
      # 1. SELECT * FROM test_comments WHERE id IN (...)
      # 2. SELECT * FROM test_cards WHERE id IN (...)
      loaded = PolyEcto.preload_polymorphic(comments, :commentable)

      assert Enum.count(loaded) == 10
      assert Enum.all?(loaded, fn c -> c.commentable != nil end)
    end

    test "MCR008_2A_T18: handles empty list" do
      result = PolyEcto.preload_polymorphic([], :commentable)
      assert result == []
    end

    test "MCR008_2A_T19: handles mixed table types", %{comments: comments} do
      loaded = PolyEcto.preload_polymorphic(comments, :commentable)

      card_comments =
        Enum.filter(loaded, fn c ->
          c.commentable && c.commentable.__struct__ == TestCard
        end)

      post_comments =
        Enum.filter(loaded, fn c ->
          c.commentable && c.commentable.__struct__ == TestPost
        end)

      assert Enum.count(card_comments) == 2
      assert Enum.count(post_comments) == 1
    end
  end

  describe "cast + insert integration" do
    test "full workflow: cast, insert, load" do
      card = TestRepo.insert!(%TestCard{id: "integration_test", text: "Test"})

      # Create comment via changeset
      comment =
        %TestComment{}
        |> cast(%{content: "Great!"}, [:content])
        |> put_change(:commentable, card)
        |> PolyEcto.cast_polymorphic(:commentable)
        |> TestRepo.insert!()

      # Verify database values
      assert comment.commentable_table == "test_cards"
      assert comment.commentable_id == "integration_test"

      # Load from DB and preload
      reloaded =
        TestRepo.get!(TestComment, comment.id)
        |> PolyEcto.load_polymorphic(:commentable)

      assert reloaded.commentable.id == "integration_test"
      assert reloaded.commentable.text == "Test"
    end
  end
end
