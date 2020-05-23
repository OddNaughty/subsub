defmodule SubSubTest do
  use ExUnit.Case
  doctest SubSub

  test "greets the world" do
    assert SubSub.hello() == :world
  end
end
