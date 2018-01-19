defmodule ExNotepad.Wx.FindDialogEvent do
  @moduledoc false

  require ExNotepad.Records
  alias ExNotepad.Records, as: R

  @spec get_flags(R.wxFindDialogEvent_ex()) :: integer()
  def get_flags(R.wxFindDialogEvent_ex(flags: value)), do: value

  @spec get_find_string(R.wxFindDialogEvent_ex()) :: String.t()
  def get_find_string(R.wxFindDialogEvent_ex(find_string: value)), do: value

  @spec get_replace_string(R.wxFindDialogEvent_ex()) :: String.t()
  def get_replace_string(R.wxFindDialogEvent_ex(replace_string: value)), do: value
end
