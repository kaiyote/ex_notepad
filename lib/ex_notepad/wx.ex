defmodule ExNotepad.Wx do
  @moduledoc false

  use Bitwise, only_operators: true

  require Record
  Record.defrecordp :wx, Record.extract(:wx, from_lib: "wx/include/wx.hrl")
  Record.defrecordp :wxCommand, Record.extract(:wxCommand, from_lib: "wx/include/wx.hrl")
  Record.defrecordp :wxStyledText, Record.extract(:wxStyledText, from_lib: "wx/include/wx.hrl")

  require ExNotepad.Records
  alias ExNotepad.File, as: F
  alias ExNotepad.Records, as: R
  alias ExNotepad.{Config, Font, Menu, Print, Text, StatusBar, Util}

  @behaviour :wx_object
  @type state :: R.wx_state()
  @opaque window :: R.window()
  @type exnotepad :: :wxWindow.wxWindow()
  @type wx :: wx()

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

  @spec handle_event(wx(), state()) :: {:noreply, state()} | {:stop, :normal, state()}
  def handle_event(wx(event: wxStyledText(type: :stc_modified) = stc_event), s) do
    m_type = wxStyledText stc_event, :modificationType
    cond do
      (m_type &&& :wx_const.wxSTC_MOD_BEFOREINSERT) > 0 ->
        event_pos = wxStyledText stc_event, :position
        mod_end = event_pos + wxStyledText(stc_event, :length)
        {:noreply, R.wx_state(s, select_start: min(R.wx_state(s, :select_start), event_pos),
                                 select_end: max(R.wx_state(s, :select_end), mod_end))}

      (m_type &&& @undo_redo_end) === @undo_redo_end ->
        rend = wxStyledText(stc_event, :position) + wxStyledText(stc_event, :length)
        :wxStyledTextCtrl.setSelection R.wx_state(s, :textctrl),
                                       R.wx_state(s, :select_start),
                                       max(rend, R.wx_state(s, :select_end))
        {:noreply, R.wx_state(s, select_start: -1, select_end: -1)}

      true -> {:noreply, s}
    end
  end
  def handle_event(wx(event: wxStyledText(type: :stc_updateui)), s) do
    s
    |> check_empty_document()
    |> check_updated_position()
    |> check_has_selection()
    |> (fn s3 -> {:noreply, s3} end).()
  end

  @spec stop_me(state()) :: {:stop, :normal, state()} | {:noreply, state()}
  defp stop_me(s) do
    case how_to_stop() do
      :normal ->
        {:stop, :normal, s}
      :init ->
        :init.stop()
        {:noreply, s}
      {:application, name} ->
        Application.stop name
        {:noreply, s}
    end
  end

  @spec how_to_stop() :: :normal | :init | {:application, atom()}
  defp how_to_stop do
    case :application.info() do
      :undefined -> :normal
      {:ok, app} ->
        started = :proplists.get_value :started, :application.info(), []
        case :proplists.get_value app, started do
          :undefined -> :normal
          :permanent -> :init
          _ -> {:application, app}
        end
    end
  end

  @spec config_save(state()) :: window()
  defp config_save(R.wx_state(frame: frame)) do
    {x, y, w, h} = :wxWindow.getScreenRect frame
    R.window x: x, y: y, width: w, height: h
  end

  @spec create_main_frame(R.missing() | window()) :: :wxFrame.wxFrame()
  defp create_main_frame(R.window() = cfg) do
    frame = :wxFrame.new :wx.null(),
                         :wx_const.wxID_ANY,
                         window_title(nil),
                         pos: {R.window(cfg, :x), R.window(cfg, :y)},
                         size: {R.window(cfg, :width), R.window(cfg, :height)}
    configure_frame frame
  end
  defp create_main_frame(_), do: create_main_frame R.window(x: 100, y: 50, width: 600, height: 480)

  @spec configure_frame(:wxFrame.wxFrame()) :: :wxFrame.wxFrame()
  defp configure_frame(frame) do
    set_icon frame

    :wxFrame.connect frame, :close_window
    :wxFrame.connect frame, :command_menu_selected

    frame
  end

  @spec set_icon(:wxFrame.wxFrame()) :: :ok
  defp set_icon(frame) do
    priv_dir = ExNotepad |> :code.priv_dir() |> List.to_string()
    case File.dir? priv_dir do
      true -> set_icon_from_file frame, priv_dir, "icon.ico"
      false -> set_icon_from_script frame, Path.join(["ex_notepad", "ebin", "icon32.raw"])
    end
  end

  @spec set_icon_from_file(:wxFrame.wxFrame(), String.t(), String.t()) :: :ok
  defp set_icon_from_file(frame, dir, name) do
    icon_file = Path.join dir, name
    icon = :wxIcon.new icon_file, type: :wx_const.wxBITMAP_TYPE_ICO
    :wxFrame.setIcon frame, icon
    :wxIcon.destroy icon
  end

  @spec set_icon_from_script(:wxFrame.wxFrame(), String.t()) :: :ok
  defp set_icon_from_script(frame, name) do
    script_file = :escript.script_name()

    case :escript.extract script_file, [] do
      {:ok, [_, _, _, {:archive, escript}]} ->
        case :zip.unzip zip_part(escript), [:memory, {:file_list, [name]}] do
          {:ok, [{_, raw_data}]} ->
            image = image_from_raw_data raw_data
            bitmap = :wxBitmap.new image
            icon = :wxIcon.new()
            :wxIcon.copyFromBitmap icon, bitmap
            :wxFrame.setIcon frame, icon
            :wxIcon.destroy icon
            :wxBitmap.destroy bitmap
            :wxImage.destroy image
          r ->
            :io.format("Cannot load icon ~p from script: ~n~p~n", [name, r])
        end
      _ ->
        :io.format("Cannot load icon, maybe is not running as script")
    end
  end

  @spec zip_header() :: binary()
  defp zip_header, do: <<"PK", 3, 4>>

  @spec zip_part(binary()) :: binary()
  defp zip_part(escript) do
    {start, _} = :binary.match escript, zip_header(), []
    binary_part escript, start, byte_size(escript) - start
  end

  @spec image_from_raw_data(binary()) :: :wxImage.wxImage()
  defp image_from_raw_data(raw_data) do
    <<image_width::size(32), image_height::size(32),
      rgb_len::size(32), rgb_data::binary - size(rgb_len),
      alpha_len::size(32), alpha_data::binary - size(alpha_len)>> = raw_data

    image = :wxImage.new image_width, image_height, rgb_data
    :wxImage.setAlpha image, alpha_data
    image
  end

  @spec window_title(String.t() | R.missing()) :: String.t()
  defp window_title(filename) do
    simple_name = F.simple_name filename
    "#{simple_name} - #{R.app_name} #{Util.get_version}"
  end

  @spec set_window_title(:wxFrame.wxFrame(), String.t() | R.missing()) :: any()
  defp set_window_title(frame, filename), do: :wxFrame.setTitle frame, window_title(filename)

  @spec get_find_string(R.fr_data() | R.missing()) :: String.t()
  defp get_find_string(frdata) when frdata in [nil, :undefined], do: ""
  defp get_find_string(frdata), do: :wxFindReplaceData.getFindString frdata

  @spec check_empty_document(state()) :: state()
  defp check_empty_document(R.wx_state(empty_state: old_empty) = s) do
    case :wxStyledTextCtrl.getLength(R.wx_state(s, :textctrl)) === 0 do
      ^old_empty -> s
      new_empty ->
        :wxMenuBar.enable R.wx_state(s, :menu), :wx_const.wxID_FIND, not(new_empty)
        :wxMenuBar.enable R.wx_state(s, :menu), R.menu_edit_findnext, not(new_empty)
        R.wx_state s, empty_state: new_empty
    end
  end

  @spec check_updated_position(state()) :: state()
  defp check_updated_position(R.wx_state(position: old_position) = s) do
    case :wxStyledTextCtrl.getCurrentPos R.wx_state(s, :textctrl) do
      ^old_position -> s
      new_position ->
        StatusBar.update_position R.wx_state(s, :statusbar), R.wx_state(s, :textctrl), new_position
        R.wx_state s, position: new_position
    end
  end

  @spec check_has_selection(state()) :: state()
  defp check_has_selection(R.wx_state(is_selecting: was_selecting) = s) do
    case Text.has_selection R.wx_state(s, :textctrl) do
      ^was_selecting -> s
      new_selecting ->
        :wxMenuBar.enable R.wx_state(s, :menu), :wx_const.wxID_CUT, new_selecting
        :wxMenuBar.enable R.wx_state(s, :menu), :wx_const.wxID_COPY, new_selecting
        :wxMenuBar.enable R.wx_state(s, :menu), :wx_const.wxID_DELETE, new_selecting
        R.wx_state s, is_selecting: new_selecting
    end
  end

  @spec open_help() :: boolean()
  defp open_help, do: :wx_misc.launchDefaultBrowser "https://github.com/kaiyote/ex_notepad"
end
