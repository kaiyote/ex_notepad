defmodule ExNotepad.Print do
  @moduledoc false

  @opaque t :: :wxHtmlEasyPrinting.wxHtmlEasyPrinting() | nil

  @spec init() :: t()
  def print, do: nil
end
