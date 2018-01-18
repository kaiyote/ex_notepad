defmodule ExNotepadTest do
  use ExUnit.Case
  doctest ExNotepad

  test "greets the world" do
    assert ExNotepad.hello() == :world
  end
end
