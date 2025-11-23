defmodule PolyEcto.HelpersTest do
  use ExUnit.Case, async: false

  setup do
    # Set test config (async: false to prevent race conditions)
    Application.put_env(:polyecto, :config, PolyEctoTest.Config)
    :ok
  end

  describe "repo/0" do
    test "MCR008_1A_T3: returns configured repo" do
      assert PolyEcto.Helpers.repo() == PolyEcto.TestRepo
    end
  end

  describe "get_schema/1" do
    test "MCR008_1A_T4: returns nil for unknown table" do
      assert PolyEcto.Helpers.get_schema("unknown_table") == nil
    end

    test "returns schema module for known table" do
      assert PolyEcto.Helpers.get_schema("test_cards") == PolyEctoTest.TestCard
      assert PolyEcto.Helpers.get_schema("test_comments") == PolyEctoTest.TestComment
    end
  end

  describe "get_table_name/1" do
    test "MCR008_1A_T5: extracts table name from schema" do
      assert PolyEcto.Helpers.get_table_name(PolyEctoTest.TestCard) == "test_cards"
      assert PolyEcto.Helpers.get_table_name(PolyEctoTest.TestComment) == "test_comments"
    end
  end

  describe "get_primary_key_value/1" do
    test "MCR008_1A_T6: extracts id from struct" do
      card = %PolyEctoTest.TestCard{id: "card_123", text: "Hello"}
      assert PolyEcto.Helpers.get_primary_key_value(card) == "card_123"
    end

    test "MCR008_1A_T7: works with UUID" do
      uuid = Ecto.UUID.generate()
      comment = %PolyEctoTest.TestComment{id: uuid, content: "Test"}
      assert PolyEcto.Helpers.get_primary_key_value(comment) == uuid
    end
  end
end
