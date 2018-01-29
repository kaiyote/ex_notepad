defmodule ExNotepad.Wx do
  @moduledoc false

  use Bitwise, only_operators: true

  require Record
  Record.defrecordp :wx, Record.extract(:wx, from_lib: "wx/include/wx.hrl")
  Record.defrecordp :wxCommand, Record.extract(:wxCommand, from_lib: "wx/include/wx.hrl")

  require ExNotepad.Records
  alias ExNotepad.Records, as: R
  alias ExNotepad.{Config, Font, Menu, Print, Text, StatusBar}

  @behaviour :wx_object
  @type state :: R.wx_state()
  @opaque window :: R.window()
  @type exnotepad :: :wxWindow.wxWindow()

  defmacrop menu_event(id) do
    quote do
      wx id: unquote(id), event: wxCommand(type: :command_menu_selected)
    end
  end

  defmacrop menu_event(id, cmd_value) do
    quote do
      wx id: unquote(id), event: wxCommand(type: :command_menu_selected, commandInt: cmd_value)
    end
  end

  @undo_redo_end :wx_const.wxSTC_LASTSTEPINUNDOREDO ||| :wx_const.wxSTC_MOD_INSERTTEXT

  @spec start() :: exnotepad() | {:error, any()}
  def start, do: :wx_object.start __MODULE__, [], []

  @spec start(String.t()) :: exnotepad() | {:error, any()}
  def start(filename), do: :wx_object.start __MODULE__, [filename], []

  @spec start_link() :: exnotepad() | {:error, any()}
  def start_link, do: :wx_object.start_link __MODULE__, [], []

  @spec start_link(String.t()) :: exnotepad() | {:error, any()}
  def start_link(filename), do: :wx_object.start_link __MODULE__, [filename], []

  @spec stop(exnotepad()) :: :ok
  def stop(exnotepad), do: :wx_object.stop exnotepad

  @spec wait_forever(exnotepad()) :: :ok
  def wait_forever(exnotepad) do
    :wx_object.call exnotepad, :noreply
  rescue
    err -> err
  end

  @spec config_check(window()) :: window()
  def config_check(R.window(x: x, y: y, width: w, height: h) =  c)
  when is_integer(x) and is_integer(y) and is_integer(w) and w > 0 and is_integer(h) and h > 0 do
    c
  end
  def config_check(_), do: nil

  @spec init(list()) :: {:wxFrame.wxFrame(), state()}
  def init(args) do
    :wx.new()
    config = Config.load()

    font = Font.load R.config(config, :font)
    frame = create_main_frame R.config(config, :window)
    menu_bar = Menu.create frame
    text_ctrl = Text.create_control frame, font
    status_bar = StatusBar.create frame

    want_status_bar = R.config config, :status_bar
    want_word_wrap = R.config(config, :word_wrap)

    :wxMenuBar.check menu_bar, R.menu_view_statusbar(), want_status_bar
    :wxMenuBar.check menu_bar, R.menu_format_wordwrap(), want_word_wrap

    case {want_word_wrap, want_status_bar} do
      {true, _} ->
        :wxStyledTextCtrl.setWrapMode text_ctrl, 1
        :wxMenuBar.enable menu_bar, R.menu_view_statusbar(), false
        :wxMenuBar.enable menu_bar, R.menu_edit_goto, false
        StatusBar.set_visible status_bar, false
      {_, false} -> StatusBar.set_visible status_bar, false
      {_, true} -> :ok
    end

    case args do
      [filename] -> send self(), {:open_on_init, filename}
      _ -> nil
    end

    :wxFrame.show frame
    :wxFrame.raise frame
    :wxFrame.setFocus text_ctrl

    {frame, R.wx_state(frame: frame,
                       textctrl: text_ctrl,
                       menu: menu_bar,
                       statusbar: status_bar,
                       font: font,
                       filename: :undefined,
                       print: Print.init())}
  end

  defp create_main_frame(_), do: :wxFrame.new :wx.null(), :wx_const.wxID_ANY, "IMA TITLE", []
end
