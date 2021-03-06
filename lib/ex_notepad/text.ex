defmodule ExNotepad.Text do
  @moduledoc false

  use Bitwise, only_operators: true

  require ExNotepad.Records
  alias ExNotepad.Records, as: R
  alias ExNotepad.{Font, Util}

  @match_case :wx_const.wxFR_MATCHCASE

  @spec create_control(:wxFrame.wxFrame(), :wxFont.wxFont()) :: R.text_ctrl()
  def create_control(frame, font) do
    text_ctrl = :wxStyledTextCtrl.new frame

    :wxStyledTextCtrl.setScrollWidth text_ctrl, 1

    :wxStyledTextCtrl.setMarginWidth text_ctrl, 1, 0

    case font do
      :undefined ->
        f = Font.default_font()
        :wxStyledTextCtrl.styleSetFont text_ctrl, :wx_const.wxSTC_STYLE_DEFAULT, f
        Font.destroy f
      _ ->
        :ok#:wxStyledTextCtrl.styleSetFont text_ctrl, :wx_const.wxSTC_STYLE_DEFAULT, font
    end

    :wxStyledTextCtrl.setSelBackground text_ctrl, true, {00, 0x78, 0xd7}
    :wxStyledTextCtrl.setSelForeground text_ctrl, true, {255, 255, 255}

    :wxStyledTextCtrl.connect text_ctrl, :stc_savepointleft

    :wxStyledTextCtrl.connect text_ctrl, :stc_modified
    :wxStyledTextCtrl.setModEventMask text_ctrl, :wx_const.wxSTC_PERFORMED_REDO |||
                                                 :wx_const.wxSTC_PERFORMED_UNDO

    :wxStyledTextCtrl.connect text_ctrl, :stc_updateui

    :wxStyledTextCtrl.connect text_ctrl, :key_up, skip: true

    configure_keys text_ctrl

    text_ctrl
  end

  @spec has_selection(R.text_ctrl()) :: boolean()
  def has_selection(text_ctrl) do
    case :wxStyledTextCtrl.getSelection text_ctrl do
      {x, x} -> false
      _ -> true
    end
  end

  @spec search(R.text_ctrl(), R.fr_data()) :: :ok
  def search(text_ctrl, fr_data) do
    find_string = :wxFindReplaceData.getFindString fr_data
    flags = :wxFindReplaceData.getFlags fr_data

    search_flags = case flags &&& @match_case do
      @match_case -> :wx_const.wxSTC_FIND_MATCHCASE
      0 -> 0
    end

    {old_sel_start, old_sel_end} = :wxStyledTextCtrl.getSelection text_ctrl

    fr_down = :wx_const.wxFR_DOWN
    pos = case flags &&& fr_down do
      ^fr_down ->
        current_pos = :wxStyledTextCtrl.getCurrentPos text_ctrl
        :wxStyledTextCtrl.gotoPos text_ctrl, current_pos
        :wxStyledTextCtrl.searchAnchor text_ctrl
        :wxStyledTextCtrl.searchNext text_ctrl, search_flags, find_string
      _ ->
        :wxStyledTextCtrl.searchAnchor text_ctrl
        :wxStyledTextCtrl.searchPrev text_ctrl, search_flags, find_string
    end

    case pos do
      -1 ->
        :wxStyledTextCtrl.setSelection text_ctrl, old_sel_start, old_sel_end
        message = ~s|Cannot find "#{find_string}"|
        Util.simple_dialog message, :wx_const.wxICON_INFORMATION
      _ ->
        {s1, s2} = :wxStyledTextCtrl.getSelection text_ctrl
        :wxStyledTextCtrl.gotoPos text_ctrl, s2
        :wxStyledTextCtrl.setSelection text_ctrl, s1, s2
    end
  end

  @spec replace(R.text_ctrl(), R.fr_data(), String.t()) :: :ok
  def replace(text_ctrl, fr_data, replacement) do
    verify_search(text_ctrl, fr_data) and :wxStyledTextCtrl.replaceSelection(text_ctrl, replacement)
  end

  @spec replace_all(R.text_ctrl(), String.t(), String.t(), integer()) :: :ok
  def replace_all(text_ctrl, search_string, replace_to, flags) do
    :wxStyledTextCtrl.gotoPos text_ctrl, 0

    search_flags = case flags &&& @match_case do
      @match_case -> :wx_const.wxSTC_FIND_MATCHCASE
      0 -> 0
    end

    text_length = :wxStyledTextCtrl.getLength text_ctrl

    :wxStyledTextCtrl.setTargetStart text_ctrl, 0
    :wxStyledTextCtrl.setTargetEnd text_ctrl, text_length
    :wxStyledTextCtrl.setSearchFlags text_ctrl, search_flags

    case :wxStyledTextCtrl.searchInTarget text_ctrl, search_string do
      -1 -> :ok
      _ ->
        :wxStyledTextCtrl.beginUndoAction text_ctrl
        undoall_hack text_ctrl
        internal_replace_all text_ctrl, search_string, replace_to
    end
  end

  @spec verify_search(R.text_ctrl(), R.fr_data()) :: boolean()
  defp verify_search(text_ctrl, fr_data) do
    case :wxStyledTextCtrl.getSelection text_ctrl do
      {x, x} -> false
      {sel_begin, sel_end} ->
        search_string = :wxFindReplaceData.getFindString fr_data
        flags = :wxFindReplaceData.getFlags fr_data
        search_flags = case flags &&& @match_case do
          @match_case -> :wx_const.wxSTC_FIND_MATCHCASE
          0 -> 0
        end

        :wxStyledTextCtrl.targetFromSelection text_ctrl
        :wxStyledTextCtrl.setSearchFlags text_ctrl, search_flags

        :wxStyledTextCtrl.searchInTarget(text_ctrl, search_string) >= 0
          and :wxStyledTextCtrl.getTargetStart(text_ctrl) === sel_begin
          and :wxStyledTextCtrl.getTargetEnd(text_ctrl) === sel_end
    end
  end

  @spec internal_replace_all(R.text_ctrl(), String.t(), String.t()) :: :ok
  defp internal_replace_all(text_ctrl, search_string, replace_to) do
    case :wxStyledTextCtrl.searchInTarget text_ctrl, search_string do
      -1 ->
        undoall_hack text_ctrl
        :wxStyledTextCtrl.gotoPos text_ctrl, 0
        :wxStyledTextCtrl.endUndoAction text_ctrl
      _ ->
        :wxStyledTextCtrl.replaceTarget text_ctrl, replace_to
        :wxStyledTextCtrl.setTargetStart text_ctrl, :wxStyledTextCtrl.getTargetEnd(text_ctrl)
        :wxStyledTextCtrl.setTargetEnd text_ctrl, :wxStyledTextCtrl.getLength(text_ctrl)
        internal_replace_all text_ctrl, search_string, replace_to
    end
  end

  @spec undoall_hack(R.text_ctrl()) :: :ok
  defp undoall_hack(text_ctrl) do
    t = :wxStyledTextCtrl.getText text_ctrl
    :wxStyledTextCtrl.clearAll text_ctrl
    :wxStyledTextCtrl.appendText text_ctrl, t
  end

  @none :wx_const.wxSTC_SCMOD_NORM
  @shift :wx_const.wxSTC_SCMOD_SHIFT
  @ctrl :wx_const.wxSTC_SCMOD_CTRL
  @ctrlshift @shift ||| @ctrl

  defmacrop assign(key, meta, cmd) do
    quote do
      :wxStyledTextCtrl.cmdKeyAssign var!(text_ctrl), unquote(key), unquote(meta), unquote(cmd)
    end
  end

  @spec configure_keys(R.text_ctrl()) :: :ok
  defp configure_keys(text_ctrl) do
    :wxStyledTextCtrl.cmdKeyClearAll text_ctrl

    assign :wx_const.wxSTC_KEY_UP, @none, :wx_const.wxSTC_CMD_LINEUP
    assign :wx_const.wxSTC_KEY_DOWN, @none, :wx_const.wxSTC_CMD_LINEDOWN
    assign :wx_const.wxSTC_KEY_LEFT, @none, :wx_const.wxSTC_CMD_CHARLEFT
    assign :wx_const.wxSTC_KEY_RIGHT, @none, :wx_const.wxSTC_CMD_CHARRIGHT
    assign :wx_const.wxSTC_KEY_LEFT, @ctrl, :wx_const.wxSTC_CMD_WORDLEFT
    assign :wx_const.wxSTC_KEY_RIGHT, @ctrl, :wx_const.wxSTC_CMD_WORDRIGHT
    assign :wx_const.wxSTC_KEY_UP, @shift, :wx_const.wxSTC_CMD_LINEUPEXTEND
    assign :wx_const.wxSTC_KEY_DOWN, @shift, :wx_const.wxSTC_CMD_LINEDOWNEXTEND
    assign :wx_const.wxSTC_KEY_LEFT, @shift, :wx_const.wxSTC_CMD_CHARLEFTEXTEND
    assign :wx_const.wxSTC_KEY_RIGHT, @shift, :wx_const.wxSTC_CMD_CHARRIGHTEXTEND

    assign :wx_const.wxSTC_KEY_LEFT, @ctrlshift, :wx_const.wxSTC_CMD_WORDLEFTEXTEND
    assign :wx_const.wxSTC_KEY_RIGHT, @ctrlshift, :wx_const.wxSTC_CMD_WORDRIGHTEXTEND

    assign :wx_const.wxSTC_KEY_PRIOR, @none, :wx_const.wxSTC_CMD_PAGEUP
    assign :wx_const.wxSTC_KEY_NEXT, @none, :wx_const.wxSTC_CMD_PAGEDOWN

    assign :wx_const.wxSTC_KEY_PRIOR, @shift, :wx_const.wxSTC_CMD_PAGEUPEXTEND
    assign :wx_const.wxSTC_KEY_NEXT, @shift, :wx_const.wxSTC_CMD_PAGEDOWNEXTEND

    assign :wx_const.wxSTC_KEY_HOME, @none, :wx_const.wxSTC_CMD_HOME
    assign :wx_const.wxSTC_KEY_END, @none, :wx_const.wxSTC_CMD_LINEEND

    assign :wx_const.wxSTC_KEY_HOME, @shift, :wx_const.wxSTC_CMD_HOMEEXTEND
    assign :wx_const.wxSTC_KEY_END, @shift, :wx_const.wxSTC_CMD_LINEENDEXTEND

    assign :wx_const.wxSTC_KEY_HOME, @ctrl, :wx_const.wxSTC_CMD_DOCUMENTSTART
    assign :wx_const.wxSTC_KEY_END, @ctrl, :wx_const.wxSTC_CMD_DOCUMENTEND

    assign :wx_const.wxSTC_KEY_HOME, @ctrlshift, :wx_const.wxSTC_CMD_DOCUMENTSTARTEXTEND
    assign :wx_const.wxSTC_KEY_END, @ctrlshift, :wx_const.wxSTC_CMD_DOCUMENTENDEXTEND

    assign :wx_const.wxSTC_KEY_DELETE, @none, :wx_const.wxSTC_CMD_CLEAR
    assign :wx_const.wxSTC_KEY_BACK, @none, :wx_const.wxSTC_CMD_DELETEBACK
    assign :wx_const.wxSTC_KEY_DELETE, @shift, :wx_const.wxSTC_CMD_DELETEBACK
    assign :wx_const.wxSTC_KEY_DELETE, @ctrl, :wx_const.wxSTC_CMD_DELLINERIGHT

    assign :wx_const.wxSTC_KEY_INSERT, @ctrl, :wx_const.wxSTC_CMD_COPY
    assign :wx_const.wxSTC_KEY_INSERT, @shift, :wx_const.wxSTC_CMD_PASTE

    assign ?J, @ctrl, :wx_const.wxSTC_CMD_NEWLINE
    assign ?M, @ctrl, :wx_const.wxSTC_CMD_NEWLINE
    assign ?I, @ctrl, :wx_const.wxSTC_CMD_TAB

    assign :wx_const.wxSTC_KEY_ESCAPE, @none, :wx_const.wxSTC_CMD_CANCEL
    assign :wx_const.wxSTC_KEY_ESCAPE, @shift, :wx_const.wxSTC_CMD_CANCEL
  end
end
