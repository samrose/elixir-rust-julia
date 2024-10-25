defmodule JuliaBridgeTest do
  use ExUnit.Case
  doctest JuliaBridge

  test "greets the world" do
    assert JuliaBridge.hello() == :world
  end
end
