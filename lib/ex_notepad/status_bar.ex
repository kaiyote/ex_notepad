defmodule ExNotepad.StatusBar do
  @moduledoc false

  require ExNotepad.Records
  alias ExNotepad.Records, as: R

  @spec create(:wxFrame.wxFrame()) :: R.statusbar()
  def create(frame) do
    status_bar = :wxFrame.createStatusBar frame, number: 2
    :wxStatusBar.setFieldsCount status_bar, 2, widths: [-77, -23]
    R.statusbar control: status_bar, frame: frame
  end

  @spec update_position(R.statusbar(), :wxStyledTextCtrl.wxStyledTextCtrl(), integer()) :: :ok
  def update_position(R.statusbar(control: status_bar), text_ctrl, position) do
    line = :wxStyledTextCtrl.lineFromPosition text_ctrl, position

    column = position - :wxStyledTextCtrl.positionFromLine text_ctrl, line

    text = "  Ln #{line + 1}, Col #{column + 1}"

    :wxStatusBar.setStatusText status_bar, text, number: 1
  end

  @spec set_visible(R.statusbar(), boolean()) :: :ok
  def set_visible(R.statusbar(control: status_bar, frame: frame), true) do
    :wxStatusBar.show status_bar
    :wxFrame.sendSizeEvent frame
  end
  def set_visible(R.statusbar(control: status_bar, frame: frame), false) do
    :wxStatusBar.hide status_bar
    :wxFrame.sendSizeEvent frame
  end
end
