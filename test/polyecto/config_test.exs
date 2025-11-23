defmodule PolyEcto.ConfigTest do
  use ExUnit.Case, async: false

  describe "PolyEcto.config/0" do
    test "MCR008_1A_T1: raises error when config not set" do
      # Save current config
      original_config = Application.get_env(:polyecto, :config)

      try do
        # Clear config
        Application.delete_env(:polyecto, :config)

        assert_raise RuntimeError, ~r/PolyEcto config not set/, fn ->
          PolyEcto.config()
        end
      after
        # Restore config
        if original_config do
          Application.put_env(:polyecto, :config, original_config)
        end
      end
    end

    test "MCR008_1A_T2: returns config module when set" do
      # Save current config
      original_config = Application.get_env(:polyecto, :config)

      try do
        # Set test config
        Application.put_env(:polyecto, :config, PolyEctoTest.Config)

        assert PolyEcto.config() == PolyEctoTest.Config
      after
        # Restore config
        if original_config do
          Application.put_env(:polyecto, :config, original_config)
        else
          Application.delete_env(:polyecto, :config)
        end
      end
    end
  end
end
