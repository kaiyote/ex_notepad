defmodule ExNotepad.File do
  @moduledoc false

  require ExNotepad.Records
  alias Elixir.File, as: F
  alias ExNotepad.Records, as: R
  alias ExNotepad.Util

  use Bitwise, only_operators: true

  @ok :wx_const.wxID_OK
  @yes :wx_const.wxID_YES
  @no :wx_const.wxID_NO
  @cancel :wx_const.wxID_CANCEL

  @spec simple_name(String.t() | nil) :: String.t()
  def simple_name(nil), do: "Untitled"
  def simple_name(filename), do: Path.basename filename

  @spec save_buffer(R.text_ctrl(), String.t(), boolean()) :: {:ok | :error, String.t()}
  def save_buffer(text_ctrl, filename, true), do: save_buffer_as text_ctrl, filename
  def save_buffer(text_ctrl, filename, false), do: save_buffer text_ctrl, filename

  @spec can_destroy_buffer(R.text_ctrl(), String.t()) :: boolean()
  def can_destroy_buffer(text_ctrl, filename) do
    case :wxStyledTextCtrl.getModify text_ctrl do
      true -> not(ask_save_buffer(text_ctrl, filename))
      false -> true
    end
  end

  @spec ask_save_buffer(R.text_ctrl(), String.t()) :: boolean()
  def ask_save_buffer(text_ctrl, filename) do
    message = "Do you want to save changes to #{simple_name filename}?"
    style = :wx_const.wxYES_NO ||| :wx_const.wxCANCEL ||| :wx_const.wxCENTRE

    case Util.simple_dialog message, style do
      @yes -> Enum.at(save_buffer(text_ctrl, filename), 1) === :ok
      @no -> true
      @cancel -> false
    end
  end

  @spec load_buffer(R.text_ctrl(), String.t() | nil) :: :ok | :error
  def load_buffer(text_ctrl, filename) do
    case F.stat filename do
      {:error, _} -> :error
      {:ok, %F.Stat{type: :directory}} -> :error
      _ ->
        case :wxStyledTextCtrl.loadFile text_ctrl, filename do
          true ->
            Util.refresh_scroll_width text_ctrl
            :wxStyledTextCtrl.emptyUndoBuffer text_ctrl
            :ok
          false -> :error
        end
    end
  end

  @spec show_open_dialog(:wxWindow.wxWindow(), R.text_ctrl()) :: nil | {:ok, String.t()}
  def show_open_dialog(parent, text_ctrl) do
    dialog = :wxFileDialog.new parent,
                               style: :wx_const.wxFD_OPEN ||| :wx_const.wxFD_FILE_MUST_EXIST,
                               wildCard: "Text Documents (*.txt)|*.txt|All Files (*.*)|*.*"

    try do
      case :wxDialog.showModal dialog do
        @ok ->
          full_filename = dialog |> :wxFileDialog.getPath() |> List.to_string()
          case load_buffer text_ctrl, full_filename do
            :ok -> {:ok, full_filename}
            :error -> nil
          end
        _ -> nil
      end
    after
      :wxFileDialog.destroy dialog
    end
  end

  @spec ensure_file(String.t()) :: {:yes, String.t()} | :no | :cancel
  def ensure_file(filename) do
    case {:filelib.is_file(filename), Path.extname(filename)} do
      {false, ""} -> ensure_file "#{filename}.txt"
      {false, _} -> ask_create_file filename
      {true, _} ->
        case :filelib.is_dir filename do
          true -> :no
          false -> {:yes, filename}
        end
    end
  end

  @spec save_buffer_as(R.text_ctrl(), nil | String.t()) :: {:ok | :error, String.t()}
  defp save_buffer_as(text_ctrl, nil), do: save_buffer_as text_ctrl, "*.txt"
  defp save_buffer_as(text_ctrl, initial_name) do
    dialog = :wxFileDialog.new :wx.null(),
                               style: :wx_const.wxFD_SAVE ||| :wx_const.wxFD_OVERWRITE_PROMPT,
                               wildCard: "Text Documents (*.txt)|*.txt|All Files (*.*)|*.*",
                               defaultFile: initial_name
    try do
      case :wxDialog.showModal dialog do
        @ok -> save_buffer text_ctrl, dialog |> :wxFileDialog.getPath() |> List.to_string()
        @cancel -> {:error, "cancelled"}
      end
    after
      :wxFileDialog.destroy dialog
    end
  end

  @spec save_buffer(R.text_ctrl(), nil | String.t()) :: {:ok | :error, String.t()}
  defp save_buffer(text_ctrl, nil), do: save_buffer_as text_ctrl, "*.txt"
  defp save_buffer(text_ctrl, filename) do
    case :wxStyledTextCtrl.saveFile text_ctrl, filename do
      true -> {:ok, filename}
      false -> {:error, "Can't save"}
    end
  end

  @spec ask_create_file(String.t()) :: {:yes, String.t()} | :no
  defp ask_create_file(filename) do
    message = "Cannot find the #{simple_name filename} file.\n\nDo you want to create a new file?"
    style = :wx_const.wxYES_NO ||| :wx_const.wxCANCEL |||
            :wx_const.wxCENTRE ||| :wx_const.wxICON_EXCLAMATION

    case Util.simple_dialog message, style do
      @yes -> create_empty_or_no filename
      @no -> :no
      @cancel -> :cancel
    end
  end

  @spec create_empty_or_no(String.t()) :: {:yes, String.t()} | :no
  defp create_empty_or_no(filename) do
    case F.write filename, <<>> do
      :ok -> {:yes, filename}
      _ -> :no
    end
  end
end
