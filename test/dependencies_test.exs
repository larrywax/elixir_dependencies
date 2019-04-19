defmodule DependenciesTest do
  use ExUnit.Case
  doctest Dependencies

  test "greets the world" do
    assert Dependencies.hello() == :world
  end
end
