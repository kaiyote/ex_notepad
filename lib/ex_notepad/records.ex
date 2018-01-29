defmodule ExNotepad.Records do
  @moduledoc false

  require Record
  import Record
  for {label, record} <- extract_all(from: "src/records.hrl") do
    defrecord label, record
  end

  @type config :: config()
  @type font :: font()
  @type statusbar :: statusbar()
  @type wxFindDialogEvent_ex :: wxFindDialogEvent_ex()
  @type text_ctrl :: :wxStyledTextCtrl.wxStyledTextCtrl()
  @type fr_data :: :wxFindReplaceData.wxFindReplaceData()
  @type wxFindReplaceDialog_ex :: :wxDialog.wxDialog()
  @type listener :: pid() | nil
  @type fr_event :: :find | :find_next | :replace | :replace_all | :close
  @type ctrl :: ctrl()
  @type ctrlstate :: ctrlstate()
  @type state :: state()
  @type missing :: :undefined | nil
  @type window :: window()
  @type wx_state() :: wx_state()

  def app_name, do: "ExNotepad"
  def config_file, do: "exconfig.cfg"

  def menu_edit_findnext, do: 2
  def menu_edit_goto, do: 3
  def menu_edit_insertdatetime, do: 4
  def menu_format_wordwrap, do: 5
  def menu_format_fontselect, do: 6
  def menu_view_statusbar, do: 7
  def menu_help_viewhelp, do: 8
end
