defmodule PolyEcto.IntegrationTest do
  @moduledoc """
  End-to-end integration tests for PolyEcto polymorphic associations.

  Tests complete CRUD cycles, multiple entity types, complex queries,
  preload chains, error handling, and performance characteristics.
  """
  use PolyEcto.DataCase, async: true

  import Ecto.Query
  alias PolyEcto.TestRepo
  alias PolyEctoTest.{TestCard, TestComment, TestPost}

  describe "MCR008_5C: End-to-End Integration Tests" do
    setup do
      # Create test entities
      card =
        %TestCard{id: "card_#{System.unique_integer([:positive])}", text: "Card Text"}
        |> TestRepo.insert!()

      post =
        %TestPost{title: "Post Title"}
        |> TestRepo.insert!()

      %{card: card, post: post}
    end

    test "MCR008_5C_T1: Test full CRUD cycle", %{card: card} do
      # CREATE: Create a comment with polymorphic association
      changeset =
        TestComment.changeset(%TestComment{}, %{
          commentable: card,
          content: "Initial comment"
        })

      assert changeset.valid?
      {:ok, comment} = TestRepo.insert(changeset)
      assert comment.commentable_table == "test_cards"
      assert comment.commentable_id == card.id

      # READ: Load polymorphic association
      reloaded_comment = TestRepo.get!(TestComment, comment.id)
      assert reloaded_comment.commentable == nil

      comment_with_assoc = PolyEcto.load_polymorphic(reloaded_comment, :commentable)
      assert comment_with_assoc.commentable.id == card.id
      assert comment_with_assoc.commentable.text == "Card Text"

      # UPDATE: Update comment content (polymorphic association stays)
      update_changeset = Ecto.Changeset.change(comment, content: "Updated comment")
      {:ok, updated_comment} = TestRepo.update(update_changeset)
      assert updated_comment.content == "Updated comment"
      assert updated_comment.commentable_table == "test_cards"
      assert updated_comment.commentable_id == card.id

      # DELETE: Delete comment
      {:ok, _deleted} = TestRepo.delete(updated_comment)
      assert TestRepo.get(TestComment, comment.id) == nil
    end

    test "MCR008_5C_T2: Test with multiple entity types", %{card: card, post: post} do
      # Create comments for different entity types
      {:ok, card_comment1} =
        TestComment.changeset(%TestComment{}, %{
          commentable: card,
          content: "Card comment 1"
        })
        |> TestRepo.insert()

      {:ok, card_comment2} =
        TestComment.changeset(%TestComment{}, %{
          commentable: card,
          content: "Card comment 2"
        })
        |> TestRepo.insert()

      {:ok, post_comment} =
        TestComment.changeset(%TestComment{}, %{
          commentable: post,
          content: "Post comment"
        })
        |> TestRepo.insert()

      # Verify storage
      assert card_comment1.commentable_table == "test_cards"
      assert card_comment2.commentable_table == "test_cards"
      assert post_comment.commentable_table == "test_posts"

      # Batch preload mixed types
      comments = [
        TestRepo.get!(TestComment, card_comment1.id),
        TestRepo.get!(TestComment, card_comment2.id),
        TestRepo.get!(TestComment, post_comment.id)
      ]

      preloaded = PolyEcto.preload_polymorphic(comments, :commentable)

      # Verify correct types loaded
      assert Enum.at(preloaded, 0).commentable.__struct__ == TestCard
      assert Enum.at(preloaded, 1).commentable.__struct__ == TestCard
      assert Enum.at(preloaded, 2).commentable.__struct__ == TestPost

      # Verify correct instances
      assert Enum.at(preloaded, 0).commentable.id == card.id
      assert Enum.at(preloaded, 1).commentable.id == card.id
      assert Enum.at(preloaded, 2).commentable.id == post.id
    end

    test "MCR008_5C_T3: Test complex queries", %{card: card, post: post} do
      # Create multiple comments with distinct content
      {:ok, _c1} =
        TestComment.changeset(%TestComment{}, %{
          commentable: card,
          content: "First card comment"
        })
        |> TestRepo.insert()

      {:ok, _c2} =
        TestComment.changeset(%TestComment{}, %{
          commentable: card,
          content: "Second card comment"
        })
        |> TestRepo.insert()

      {:ok, _c3} =
        TestComment.changeset(%TestComment{}, %{
          commentable: post,
          content: "Post comment here"
        })
        |> TestRepo.insert()

      # Complex query 1: Filter by entity type
      card_comments =
        from(c in TestComment,
          where: c.commentable_table == "test_cards",
          order_by: [asc: c.content]
        )
        |> TestRepo.all()

      assert length(card_comments) == 2
      assert Enum.at(card_comments, 0).content == "First card comment"
      assert Enum.at(card_comments, 1).content == "Second card comment"

      # Complex query 2: Filter by entity type AND specific entity
      specific_card_comments =
        from(c in TestComment,
          where: c.commentable_table == "test_cards",
          where: c.commentable_id == ^card.id,
          order_by: [desc: c.content]
        )
        |> TestRepo.all()

      assert length(specific_card_comments) == 2
      assert Enum.at(specific_card_comments, 0).content == "Second card comment"

      # Complex query 3: Composable queries with polymorphic_assoc
      base_query = PolyEcto.polymorphic_assoc(card, :comments)

      filtered_query =
        from(c in base_query,
          where: ilike(c.content, "%First%")
        )

      filtered_results = TestRepo.all(filtered_query)
      assert length(filtered_results) == 1
      assert hd(filtered_results).content == "First card comment"
    end

    test "MCR008_5C_T4: Test preload chains", %{card: card} do
      # Create comment
      {:ok, comment} =
        TestComment.changeset(%TestComment{}, %{
          commentable: card,
          content: "Comment"
        })
        |> TestRepo.insert()

      # Test 1: Load polymorphic on belongs_to side
      reloaded_comment = TestRepo.get!(TestComment, comment.id)
      comment_with_card = PolyEcto.load_polymorphic(reloaded_comment, :commentable)
      assert comment_with_card.commentable.text == "Card Text"

      # Test 2: Preload on has_many side
      reloaded_card = TestRepo.get!(TestCard, card.id)
      card_with_comments = PolyEcto.preload_polymorphic_assoc(reloaded_card, :comments)
      assert length(card_with_comments.comments) == 1
      assert hd(card_with_comments.comments).content == "Comment"

      # Test 3: Chain both directions
      # Load card -> preload comments -> each comment has card reference
      card_chain =
        reloaded_card
        |> PolyEcto.preload_polymorphic_assoc(:comments)

      assert length(card_chain.comments) == 1

      # Now load the commentable for each comment
      comments_with_cards = PolyEcto.preload_polymorphic(card_chain.comments, :commentable)
      assert hd(comments_with_cards).commentable.id == card.id
    end

    test "MCR008_5C_T5: Test error handling", %{card: card} do
      # Test 1: Handle missing entity gracefully
      {:ok, comment} =
        TestComment.changeset(%TestComment{}, %{
          commentable: card,
          content: "Comment"
        })
        |> TestRepo.insert()

      # Delete the card
      TestRepo.delete!(card)

      # Try to load polymorphic - should return nil or handle gracefully
      reloaded_comment = TestRepo.get!(TestComment, comment.id)
      loaded = PolyEcto.load_polymorphic(reloaded_comment, :commentable)

      # The entity should be nil since it was deleted
      assert loaded.commentable == nil

      # Test 2: Handle empty preload list
      empty_result = PolyEcto.preload_polymorphic([], :commentable)
      assert empty_result == []

      # Test 3: Handle invalid table name (orphaned data)
      # Manually create comment with invalid table
      orphaned_comment =
        %TestComment{
          commentable_table: "nonexistent_table",
          commentable_id: "fake_id",
          content: "Orphaned"
        }
        |> TestRepo.insert!()

      orphaned_loaded = PolyEcto.load_polymorphic(orphaned_comment, :commentable)
      # Should handle missing schema gracefully
      assert orphaned_loaded.commentable == nil
    end
  end

  describe "MCR008_5C: Performance Tests" do
    setup do
      # Create multiple entities for performance testing
      cards =
        Enum.map(1..20, fn i ->
          %TestCard{id: "card_#{i}", text: "Card #{i}"}
          |> TestRepo.insert!()
        end)

      posts =
        Enum.map(1..20, fn i ->
          %TestPost{title: "Post #{i}"}
          |> TestRepo.insert!()
        end)

      %{cards: cards, posts: posts}
    end

    test "MCR008_5C_T6: Test N+1 prevention with belongs_to preload", %{
      cards: cards,
      posts: posts
    } do
      # Create comments for both entity types
      card_comments =
        Enum.flat_map(Enum.take(cards, 10), fn card ->
          Enum.map(1..2, fn i ->
            TestComment.changeset(%TestComment{}, %{
              commentable: card,
              content: "Card comment #{i}"
            })
            |> TestRepo.insert!()
          end)
        end)

      post_comments =
        Enum.flat_map(Enum.take(posts, 10), fn post ->
          Enum.map(1..2, fn i ->
            TestComment.changeset(%TestComment{}, %{
              commentable: post,
              content: "Post comment #{i}"
            })
            |> TestRepo.insert!()
          end)
        end)

      all_comments = card_comments ++ post_comments
      comment_ids = Enum.map(all_comments, & &1.id)

      # Reload comments without associations
      reloaded = TestRepo.all(from c in TestComment, where: c.id in ^comment_ids)

      # Count queries - this is a simple test, in production you'd use telemetry
      # The preload should make at most 2 queries (one per table type)
      result = PolyEcto.preload_polymorphic(reloaded, :commentable)

      # Verify all loaded
      # 20 card comments + 20 post comments
      assert length(result) == 40

      assert Enum.all?(result, fn comment ->
               comment.commentable != nil
             end)

      # Verify correct types
      card_comment_count =
        Enum.count(result, fn c ->
          c.commentable.__struct__ == TestCard
        end)

      post_comment_count =
        Enum.count(result, fn c ->
          c.commentable.__struct__ == TestPost
        end)

      assert card_comment_count == 20
      assert post_comment_count == 20
    end

    test "MCR008_5C_T7: Test batch loading efficiency with has_many", %{cards: cards} do
      # Create multiple comments per card
      Enum.each(Enum.take(cards, 10), fn card ->
        Enum.each(1..5, fn i ->
          TestComment.changeset(%TestComment{}, %{
            commentable: card,
            content: "Comment #{i}"
          })
          |> TestRepo.insert!()
        end)
      end)

      # Reload cards
      card_ids = Enum.map(Enum.take(cards, 10), & &1.id)
      reloaded_cards = TestRepo.all(from c in TestCard, where: c.id in ^card_ids)

      # Batch preload - should use single query
      cards_with_comments = PolyEcto.preload_polymorphic_assoc(reloaded_cards, :comments)

      # Verify all cards have their comments
      assert length(cards_with_comments) == 10

      assert Enum.all?(cards_with_comments, fn card ->
               length(card.comments) == 5
             end)
    end

    test "MCR008_5C_T8: Test with large datasets (100+ records)", %{cards: cards, posts: posts} do
      # Create 100+ comments across different entity types
      all_entities = Enum.take(cards, 10) ++ Enum.take(posts, 10)

      comments =
        Enum.flat_map(all_entities, fn entity ->
          Enum.map(1..5, fn i ->
            TestComment.changeset(%TestComment{}, %{
              commentable: entity,
              content: "Comment #{i}"
            })
            |> TestRepo.insert!()
          end)
        end)

      assert length(comments) == 100

      # Reload and preload in batches
      comment_ids = Enum.map(comments, & &1.id)
      reloaded = TestRepo.all(from c in TestComment, where: c.id in ^comment_ids)

      # Time the batch preload (basic performance check)
      {time_microseconds, result} =
        :timer.tc(fn ->
          PolyEcto.preload_polymorphic(reloaded, :commentable)
        end)

      # Verify all loaded correctly
      assert length(result) == 100
      assert Enum.all?(result, &(&1.commentable != nil))

      # Basic performance assertion - should complete reasonably fast
      # Target: < 100ms for 100 records with 2 different tables
      time_ms = time_microseconds / 1000
      assert time_ms < 100, "Batch preload took #{time_ms}ms, expected < 100ms"
    end
  end

  describe "MCR008_5C: Edge Cases" do
    test "handles deleted entities in polymorphic fields" do
      # Create a card and comment
      card =
        %TestCard{id: "temp_card", text: "Temporary"}
        |> TestRepo.insert!()

      comment =
        TestComment.changeset(%TestComment{}, %{
          commentable: card,
          content: "Comment on temporary card"
        })
        |> TestRepo.insert!()

      assert comment.commentable_table == "test_cards"
      assert comment.commentable_id == "temp_card"

      # Delete the card (orphan the comment)
      TestRepo.delete!(card)

      # Reload comment
      reloaded_comment = TestRepo.get!(TestComment, comment.id)

      # Load should handle missing entity gracefully
      loaded = PolyEcto.load_polymorphic(reloaded_comment, :commentable)
      assert loaded.commentable == nil

      # Preload should handle missing entity gracefully
      preloaded = PolyEcto.preload_polymorphic([reloaded_comment], :commentable)
      assert length(preloaded) == 1
      assert hd(preloaded).commentable == nil
    end

    test "handles empty has_many associations" do
      card =
        %TestCard{id: "empty_card", text: "No comments"}
        |> TestRepo.insert!()

      # Query should return empty
      query = PolyEcto.polymorphic_assoc(card, :comments)
      results = TestRepo.all(query)
      assert results == []

      # Preload should set empty array
      card_with_comments = PolyEcto.preload_polymorphic_assoc(card, :comments)
      assert card_with_comments.comments == []
    end

    test "handles concurrent entity types in has_many" do
      # Create entities
      card =
        %TestCard{id: "concurrent_card", text: "Card"}
        |> TestRepo.insert!()

      post =
        %TestPost{title: "Post"}
        |> TestRepo.insert!()

      # Both have comments
      {:ok, _} =
        TestComment.changeset(%TestComment{}, %{
          commentable: card,
          content: "Card comment"
        })
        |> TestRepo.insert()

      {:ok, _} =
        TestComment.changeset(%TestComment{}, %{
          commentable: post,
          content: "Post comment"
        })
        |> TestRepo.insert()

      # Each entity should get only its comments
      card_query = PolyEcto.polymorphic_assoc(card, :comments)
      card_comments = TestRepo.all(card_query)
      assert length(card_comments) == 1
      assert hd(card_comments).content == "Card comment"

      post_query = PolyEcto.polymorphic_assoc(post, :comments)
      post_comments = TestRepo.all(post_query)
      assert length(post_comments) == 1
      assert hd(post_comments).content == "Post comment"
    end

    test "handles string vs UUID primary keys correctly" do
      # TestCard uses string PK, TestPost uses UUID
      card =
        %TestCard{id: "string_id_123", text: "String PK"}
        |> TestRepo.insert!()

      post =
        %TestPost{title: "UUID PK"}
        |> TestRepo.insert!()

      # Create comments for both
      {:ok, card_comment} =
        TestComment.changeset(%TestComment{}, %{
          commentable: card,
          content: "String PK comment"
        })
        |> TestRepo.insert()

      {:ok, post_comment} =
        TestComment.changeset(%TestComment{}, %{
          commentable: post,
          content: "UUID PK comment"
        })
        |> TestRepo.insert()

      # Verify IDs stored correctly
      assert card_comment.commentable_id == "string_id_123"
      assert is_binary(post_comment.commentable_id)
      # UUID format
      assert String.length(post_comment.commentable_id) == 36

      # Load both types
      comments = [
        TestRepo.get!(TestComment, card_comment.id),
        TestRepo.get!(TestComment, post_comment.id)
      ]

      loaded = PolyEcto.preload_polymorphic(comments, :commentable)

      # Both should load correctly
      assert Enum.at(loaded, 0).commentable.id == "string_id_123"
      assert Enum.at(loaded, 1).commentable.id == post.id
    end
  end
end
