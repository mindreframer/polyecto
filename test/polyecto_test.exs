defmodule PolyectoTest do
  use ExUnit.Case
  doctest PolyEcto

  test "basic module loaded" do
    assert Code.ensure_loaded?(PolyEcto)
  end
end
