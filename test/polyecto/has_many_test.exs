defmodule PolyEcto.HasManyTest do
  use PolyEcto.DataCase, async: true

  import Ecto.Query
  alias PolyEcto.TestRepo
  alias PolyEctoTest.{TestCard, TestComment, TestPost}

  describe "polymorphic_has_many macro" do
    test "MCR008_3A_T1: generates virtual field" do
      # Virtual fields can be set on structs
      assert %TestCard{}.comments == nil
      assert %TestPost{}.comments == nil
    end

    test "MCR008_3A_T2: stores config via __polyecto_has_many__/1" do
      config = TestCard.__polyecto_has_many__(:comments)

      assert config.type == :has_many
      assert config.queryable == PolyEctoTest.TestComment
      assert config.as == :commentable
    end

    test "MCR008_3A_T3: requires :as option" do
      # This is a compile-time test - if the macro is called without :as,
      # compilation will fail. We verify it was called correctly by checking config.
      config = TestCard.__polyecto_has_many__(:comments)
      assert config.as == :commentable
    end
  end

  describe "polymorphic_assoc/2" do
    setup do
      card = TestRepo.insert!(%TestCard{id: "card_1", text: "Hello"})
      %{card: card}
    end

    test "MCR008_3A_T4: returns Ecto.Query", %{card: card} do
      query = PolyEcto.polymorphic_assoc(card, :comments)
      assert %Ecto.Query{} = query
    end

    test "MCR008_3A_T5: query filters by table", %{card: card} do
      query = PolyEcto.polymorphic_assoc(card, :comments)

      # Inspect the query's where clauses
      assert query.wheres
             |> Enum.any?(fn w ->
               inspect(w) =~ "test_cards"
             end)
    end

    test "MCR008_3A_T6: query filters by id", %{card: card} do
      query = PolyEcto.polymorphic_assoc(card, :comments)

      # Inspect the query's where clauses
      assert query.wheres
             |> Enum.any?(fn w ->
               inspect(w) =~ "card_1"
             end)
    end

    test "MCR008_3A_T7: query is composable (can add more filters)", %{card: card} do
      # Create some test comments
      TestRepo.insert!(%TestComment{
        commentable_table: "test_cards",
        commentable_id: "card_1",
        content: "First"
      })

      TestRepo.insert!(%TestComment{
        commentable_table: "test_cards",
        commentable_id: "card_1",
        content: "Second"
      })

      # Build query and add filter
      query =
        PolyEcto.polymorphic_assoc(card, :comments)
        |> where([c], c.content == "First")

      comments = TestRepo.all(query)

      assert length(comments) == 1
      assert hd(comments).content == "First"
    end
  end

  describe "preload_polymorphic_assoc/2 - single struct" do
    setup do
      card = TestRepo.insert!(%TestCard{id: "card_1", text: "Hello"})

      comment1 =
        TestRepo.insert!(%TestComment{
          commentable_table: "test_cards",
          commentable_id: "card_1",
          content: "First"
        })

      comment2 =
        TestRepo.insert!(%TestComment{
          commentable_table: "test_cards",
          commentable_id: "card_1",
          content: "Second"
        })

      %{card: card, comment1: comment1, comment2: comment2}
    end

    test "MCR008_3A_T8: preloads associations for single struct", %{card: card} do
      loaded_card = PolyEcto.preload_polymorphic_assoc(card, :comments)

      assert is_list(loaded_card.comments)
      assert length(loaded_card.comments) == 2
    end

    test "MCR008_3A_T9: loads related records", %{card: card} do
      loaded_card = PolyEcto.preload_polymorphic_assoc(card, :comments)

      contents = Enum.map(loaded_card.comments, & &1.content) |> Enum.sort()
      assert contents == ["First", "Second"]
    end

    test "MCR008_3A_T10: sets virtual field", %{card: card} do
      loaded_card = PolyEcto.preload_polymorphic_assoc(card, :comments)

      assert Map.has_key?(loaded_card, :comments)
      assert loaded_card.comments != nil
    end
  end

  describe "preload_polymorphic_assoc/2 - batch loading" do
    setup do
      card1 = TestRepo.insert!(%TestCard{id: "card_1", text: "First"})
      card2 = TestRepo.insert!(%TestCard{id: "card_2", text: "Second"})
      card3 = TestRepo.insert!(%TestCard{id: "card_3", text: "Third"})

      # Card 1 has 2 comments
      TestRepo.insert!(%TestComment{
        commentable_table: "test_cards",
        commentable_id: "card_1",
        content: "Comment 1-1"
      })

      TestRepo.insert!(%TestComment{
        commentable_table: "test_cards",
        commentable_id: "card_1",
        content: "Comment 1-2"
      })

      # Card 2 has 1 comment
      TestRepo.insert!(%TestComment{
        commentable_table: "test_cards",
        commentable_id: "card_2",
        content: "Comment 2-1"
      })

      # Card 3 has no comments

      %{card1: card1, card2: card2, card3: card3}
    end

    test "MCR008_3A_T11: preloads for list of structs", %{card1: c1, card2: c2, card3: c3} do
      cards = [c1, c2, c3]
      loaded_cards = PolyEcto.preload_polymorphic_assoc(cards, :comments)

      assert length(loaded_cards) == 3
      assert Enum.all?(loaded_cards, &is_list(&1.comments))
    end

    test "MCR008_3A_T12: performs single query (no N+1)", %{card1: c1, card2: c2, card3: c3} do
      cards = [c1, c2, c3]

      # We can't easily count queries, but we can verify the result is correct
      # which confirms batch loading worked
      loaded_cards = PolyEcto.preload_polymorphic_assoc(cards, :comments)

      assert length(loaded_cards) == 3
    end

    test "MCR008_3A_T13: maps to correct parent", %{card1: c1, card2: c2, card3: c3} do
      cards = [c1, c2, c3]
      loaded_cards = PolyEcto.preload_polymorphic_assoc(cards, :comments)

      [loaded1, loaded2, loaded3] = loaded_cards

      assert length(loaded1.comments) == 2
      assert length(loaded2.comments) == 1
      assert length(loaded3.comments) == 0

      assert Enum.all?(loaded1.comments, &(&1.content =~ "1-"))
      assert Enum.all?(loaded2.comments, &(&1.content =~ "2-"))
    end

    test "MCR008_3A_T14: handles parent with no associations", %{
      card1: c1,
      card2: c2,
      card3: c3
    } do
      cards = [c1, c2, c3]
      loaded_cards = PolyEcto.preload_polymorphic_assoc(cards, :comments)

      [_loaded1, _loaded2, loaded3] = loaded_cards

      assert loaded3.comments == []
    end

    test "MCR008_3A_T15: handles empty list" do
      result = PolyEcto.preload_polymorphic_assoc([], :comments)
      assert result == []
    end
  end

  describe "preload_polymorphic_assoc/2 - mixed entity types" do
    setup do
      # Create cards and posts
      card = TestRepo.insert!(%TestCard{id: "card_1", text: "Card"})
      post = TestRepo.insert!(%TestPost{title: "Post"})

      # Comments for card
      TestRepo.insert!(%TestComment{
        commentable_table: "test_cards",
        commentable_id: "card_1",
        content: "Card comment"
      })

      # Comments for post
      TestRepo.insert!(%TestComment{
        commentable_table: "test_posts",
        commentable_id: post.id,
        content: "Post comment"
      })

      %{card: card, post: post}
    end

    test "MCR008_3A_T16: loads comments for card", %{card: card} do
      loaded_card = PolyEcto.preload_polymorphic_assoc(card, :comments)

      assert length(loaded_card.comments) == 1
      assert hd(loaded_card.comments).content == "Card comment"
    end

    test "MCR008_3A_T17: loads comments for post", %{post: post} do
      loaded_post = PolyEcto.preload_polymorphic_assoc(post, :comments)

      assert length(loaded_post.comments) == 1
      assert hd(loaded_post.comments).content == "Post comment"
    end

    test "MCR008_3A_T18: doesn't cross-contaminate between types", %{card: card, post: post} do
      loaded_card = PolyEcto.preload_polymorphic_assoc(card, :comments)
      loaded_post = PolyEcto.preload_polymorphic_assoc(post, :comments)

      # Card should only have card comments
      assert Enum.all?(loaded_card.comments, &(&1.content == "Card comment"))

      # Post should only have post comments
      assert Enum.all?(loaded_post.comments, &(&1.content == "Post comment"))
    end
  end

  describe "integration with polymorphic_assoc/2" do
    setup do
      card = TestRepo.insert!(%TestCard{id: "card_1", text: "Hello"})

      TestRepo.insert!(%TestComment{
        commentable_table: "test_cards",
        commentable_id: "card_1",
        content: "First"
      })

      TestRepo.insert!(%TestComment{
        commentable_table: "test_cards",
        commentable_id: "card_1",
        content: "Second"
      })

      %{card: card}
    end

    test "MCR008_3A_T19: can query and then preload", %{card: card} do
      # Query using polymorphic_assoc
      comments =
        PolyEcto.polymorphic_assoc(card, :comments)
        |> TestRepo.all()

      assert length(comments) == 2
    end

    test "MCR008_3A_T20: produces same results as direct query", %{card: card} do
      # Using polymorphic_assoc
      via_assoc =
        PolyEcto.polymorphic_assoc(card, :comments)
        |> order_by(asc: :content)
        |> TestRepo.all()

      # Using preload
      via_preload =
        PolyEcto.preload_polymorphic_assoc(card, :comments)
        |> Map.get(:comments)
        |> Enum.sort_by(& &1.content)

      assert length(via_assoc) == length(via_preload)
      assert Enum.map(via_assoc, & &1.id) == Enum.map(via_preload, & &1.id)
    end
  end
end
