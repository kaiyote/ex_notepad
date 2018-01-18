defmodule ExNotepad.Util do
  @moduledoc false

  alias ExNotepad.Records, as: R

  @spec simple_dialog(String.t(), integer()) :: integer()
  def simple_dialog(message, style) do
    dialog = :wxMessageDialog.new :wx.null(), message, caption: R.app_name(), style: style

    try do
      :wxMessageDialog.showModal dialog
    after
      :wxMessageDialog.destroy dialog
    end
  end

  @spec refresh_scroll_width(R.text_ctrl()) :: :ok
  def refresh_scroll_width(text_ctrl) do
    :wxStyledTextCtrl.setScrollWidth text_ctrl, max_line_length(text_ctrl)
  end

  @spec max_line_length(R.text_ctrl()) :: integer()
  defp max_line_length(text_ctrl) do
    max_line_length text_ctrl, 0, :wxStyledTextCtrl.getLineCount(text_ctrl), 0
  end

  @spec max_line_length(R.text_ctrl(), integer(), integer(), integer()) :: integer()
  defp max_line_length(text_ctrl, line_num, total_lines, max) when line_num < total_lines do
    line = :wxStyledTextCtrl.getLine text_ctrl, line_num
    length = :wxStyledTextCtrl.textWidth text_ctrl, :wx_const.wxSTC_STYLE_DEFAULT, line

    max_line_length text_ctrl, line_num + 1, total_lines, max(max, length)
  end
  defp max_line_length(_, _, _, max), do: max

  @spec get_version() :: String.t()
  def get_version do
    case Application.get_env ExNotepad, :vsn do
      nil -> nil
      version -> version
    end
  end
end
