defmodule ExNotepad.Print do
  @moduledoc false

  require ExNotepad.Records
  alias ExNotepad.Records, as: R

  @opaque t :: :wxHtmlEasyPrinting.wxHtmlEasyPrinting() | nil

  @spec init() :: t()
  def init, do: nil

  @spec page_setup(t()) :: t()
  def page_setup(nil), do: page_setup :wxHtmlEasyPrinting.new()
  def page_setup(easy_print) do
    :wxHtmlEasyPrinting.pageSetup easy_print
    easy_print
  end

  @spec print(t(), String.t(), R.font() | nil) :: t()
  def print(nil, text, font), do: print :wxHtmlEasyPrinting.new(), text, font
  def print(easy_print, text, font) when not(is_nil(font)) do
    font_name = :wxFont.getFaceName font
    font_size = :wxFont.getPointSize font
    sizes = List.duplicate 7, font_size

    :wxHtmlEasyPrinting.setFonts easy_print, font_name, font_name, sizes: sizes

    print easy_print, text, nil
  end
  def print(easy_print, text, _) do
    html_text = text_to_html text
    :wxHtmlEasyPrinting.printText easy_print, html_text
    easy_print
  end

  @spec destroy(t()) :: :ok
  def destroy(nil), do: :ok
  def destroy(easy_print), do: :wxHtmlEasyPrinting.destroy easy_print

  @spec text_to_html(String.t()) :: list(String.t())
  defp text_to_html(t) do
    [
      "<html><head></head><body><pre>",
      t |> String.to_charlist() |> Enum.map(&html_escape/1) |> Enum.join(),
      "</pre></body></html>"
    ]
  end

  @spec html_escape(char()) :: char() | String.t()
  defp html_escape(?<), do: "&lt;"
  defp html_escape(?>), do: "&gt;"
  defp html_escape(?&), do: "&amp;"
  defp html_escape(?"), do: "&quot;"
  defp html_escape(c), do: c
end
