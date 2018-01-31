defmodule ExNotepad.Wx do
  @moduledoc false
  @dialyzer {:nowarn_function, 'MACRO-menu_event': 2}
  @dialyzer {:nowarn_function, 'MACRO-menu_event': 3}
  @dialyzer {:nowarn_function, 'MACRO-is_missing': 2}

  use Bitwise, only_operators: true

  require Record
  Record.defrecordp :wx, Record.extract(:wx, from_lib: "wx/include/wx.hrl")
  Record.defrecordp :wxCommand, Record.extract(:wxCommand, from_lib: "wx/include/wx.hrl")
  Record.defrecordp :wxStyledText, Record.extract(:wxStyledText, from_lib: "wx/include/wx.hrl")
  Record.defrecordp :wxClose, Record.extract(:wxClose, from_lib: "wx/include/wx.hrl")
  Record.defrecordp :wxKey, Record.extract(:wxKey, from_lib: "wx/include/wx.hrl")

  require ExNotepad.Records
  alias ExNotepad.File, as: F
  alias ExNotepad.Records, as: R
  alias ExNotepad.{Config, Font, Menu, Print, Text, StatusBar, Util}
  alias ExNotepad.Wx.FindReplaceDialog, as: FRD

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
      wx id: unquote(id),
         event: wxCommand(type: :command_menu_selected, commandInt: unquote(cmd_value))
    end
  end

  defmacrop is_missing(x) do
    quote do
      unquote(x) in [:undefined, nil]
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
  def handle_event(wx(event: wxStyledText(type: :stc_savepointleft)), s) do
    can_undo = :wxStyledTextCtrl.canUndo R.wx_state(s, :textctrl)
    :wxMenuBar.enable R.wx_state(s, :menu), :wx_const.wxID_UNDO, can_undo
    {:noreply, s}
  end
  def handle_event(wx(event: wxClose()), s) do
    case F.can_destroy_buffer R.wx_state(s, :textctrl), R.wx_state(s, :filename) do
      true -> stop_me s
      false -> {:noreply, s}
    end
  end
  @id_exit :wx_const.wxID_EXIT
  def handle_event(menu_event(@id_exit), s) do
    case F.can_destroy_buffer R.wx_state(s, :textctrl), R.wx_state(s, :filename) do
      true -> stop_me s
      false -> {:noreply, s}
    end
  end
  @id_new :wx_const.wxID_NEW
  def handle_event(menu_event(@id_new), s) do
    ctrl = R.wx_state s, :textctrl
    case F.can_destroy_buffer ctrl, R.wx_state(s, :filename) do
      true ->
        :wxStyledTextCtrl.clearAll ctrl
        :wxStyledTextCtrl.emptyUndoBuffer ctrl
        :wxStyledTextCtrl.setScrollWidth ctrl, 1

        :wxMenuBar.enable R.wx_state(s, :menu), :wx_const.wxID_UNDO, false

        set_window_title R.wx_state(s, :frame), nil

        case R.wx_state(s, :fr_dialog) do
          dialog when is_missing dialog  ->
            clear_fr_data s
            {:noreply, R.wx_state(filename: :undefined, fr_data: :undefined)}
          _ -> {:noreply, R.wx_state(filename: :undefined)}
        end
      false -> {:noreply, s}
    end
  end
  @id_open :wx_const.wxID_OPEN
  def handle_event(menu_event(@id_open), s) do
    ctrl = R.wx_state s, :textctrl
    case F.can_destroy_buffer ctrl, R.wx_state(s, :filename) do
      true ->
        case F.show_open_dialog R.wx_state(s, :frame), ctrl do
          {:ok, full_filename} ->
            :wxMenuBar.enable R.wx_state(s, :menu), :wx_const.wxID_UNDO, false
            set_window_title R.wx_state(s, :frame), full_filename
            {:noreply, R.wx_state(s, filename: full_filename)}
          x when is_missing x -> {:noreply, s}
        end
      false -> {:noreply, s}
    end
  end
  @id_save :wx_const.wxID_SAVE
  @id_saveas :wx_const.wxID_SAVEAS
  def handle_event(menu_event(id), R.wx_state(filename: filename) = s)
  when id in [@id_save, @id_saveas] do
    force_name = id === @id_saveas
    case F.save_buffer R.wx_state(s, :textctrl), filename, force_name do
      {:ok, ^filename} -> {:noreply, s}
      {:ok, new_filename} ->
        set_window_title R.wx_state(s, :frame), new_filename
        {:noreply, R.wx_state(s, filename: new_filename)}
      {:error, _reason} -> {:noreply, s}
    end
  end
  @id_pagesetup :wx_const.wxID_PAGE_SETUP
  def handle_event(menu_event(@id_pagesetup), s) do
    {:noreply, R.wx_state(s, print: Print.page_setup(R.wx_state(s, :print)))}
  end
  @id_print :wx_const.wxID_PRINT
  def handle_event(menu_event(@id_print), s) do
    text = s |> R.wx_state(:textctrl) |> :wxStyledTextCtrl.getText() |> List.to_string()
    easy_print = Print.print R.wx_state(s, :print), text, R.wx_state(s, :font)
    {:noreply, R.wx_state(s, print: easy_print)}
  end
  @id_undo :wx_const.wxID_UNDO
  def handle_event(menu_event(@id_undo), s) do
    text_ctrl = R.wx_state(s, :textctrl)
    case :wxStyledTextCtrl.canRedo text_ctrl do
      true -> :wxStyledTextCtrl.redo text_ctrl
      false -> :wxStyledTextCtrl.undo text_ctrl
    end
    {:noreply, R.wx_state(s, select_start: :wxStyledTextCtrl.getLength(text_ctrl))}
  end
  @id_cut :wx_const.wxID_CUT
  def handle_event(menu_event(@id_cut), s) do
    :wxStyledTextCtrl.cut R.wx_state(s, :textctrl)
    {:noreply, s}
  end
  @id_copy :wx_const.wxID_COPY
  def handle_event(menu_event(@id_copy), s) do
    :wxStyledTextCtrl.copy R.wx_state(s, :textctrl)
    {:noreply, s}
  end
  @id_paste :wx_const.wxID_PASTE
  def handle_event(menu_event(@id_paste), s) do
    :wxStyledTextCtrl.paste R.wx_state(s, :textctrl)
    Util.refresh_scroll_width R.wx_state(s, :textctrl)
    {:noreply, s}
  end
  @id_delete :wx_const.wxID_DELETE
  def handle_event(menu_event(@id_delete), s) do
    :wxStyledTextCtrl.clear R.wx_state(s, :textctrl)
    {:noreply, s}
  end
  @id_find :wx_const.wxID_FIND
  @id_replace :wx_const.wxID_REPLACE
  def handle_event(menu_event(id) = event, R.wx_state(fr_data: :undefined) = s)
  when id in [@id_find, @id_replace] do
    handle_event event, R.wx_state(s, fr_data: :wxFindReplaceData.new(:wx_const.wxFR_DOWN))
  end
  def handle_event(menu_event(@id_find), R.wx_state(fr_dialog: :undefined) = s) do
    dialog_style = :wx_const.wxFR_NOWHOLEWORD
    dialog = FRD.new R.wx_state(s, :frame), R.wx_state(s, :fr_data), "Find", style: dialog_style
    FRD.connect dialog, :find_dialog_event
    :wxDialog.show dialog
    {:noreply, R.wx_state(s, fr_dialog: dialog)}
  end
  def handle_event(menu_event(@id_replace), R.wx_state(fr_dialog: :undefined) = s) do
    dialog_style = :wx_const.wxFR_REPLACEDIALOG ||| :wx_const.wxFR_NOWHOLEWORD
    dialog = FRD.new R.wx_state(s, :frame), R.wx_state(s, :fr_data), "Replace", style: dialog_style
    FRD.connect dialog, :find_dialog_event
    :wxDialog.show dialog
    {:noreply, R.wx_state(s, fr_dialog: dialog)}
  end
  def handle_event(menu_event(id), R.wx_state(fr_dialog: dialog) = s)
  when id in [@id_find, @id_replace] do
    :wxDialog.raise dialog
    {:noreply, s}
  end
  @edit_findnext R.menu_edit_findnext()
  def handle_event(menu_event(@edit_findnext) = e, s) do
    case get_find_string R.wx_state(s, :fr_data) do
      "" -> handle_event wx(e, id: @id_find), s
      _something ->
        Text.search R.wx_state(s, :textctrl), R.wx_state(s, :fr_data)
        {:noreply, s}
    end
  end
  @edit_goto R.menu_edit_goto()
  @id_ok :wx_const.wxID_OK
  def handle_event(menu_event(@edit_goto), s) do
    current_line = :wxStyledTextCtrl.getCurrentLine R.wx_state(s, :textctrl)
    dialog = :wxTextEntryDialog.new :wx.null(),
                                    "Line Number:",
                                    caption: "Go To Line",
                                    value: Integer.to_string(current_line + 1)
    try do
      case :wxTextEntryDialog.showModal dialog do
        @id_ok ->
          str_value = dialog |> :wxTextEntryDialog.getValue() |> List.to_string()
          case Integer.parse str_value do
            {n, _} when is_integer(n) and n > 0 ->
              :wxStyledTextCtrl.gotoLine R.wx_state(s, :textctrl), n - 1
            _ ->
              :ok
          end
        _ ->
          :ok
      end
    after
      :wxTextEntryDialog.destroy dialog
    end
    {:noreply, s}
  end
  @id_selectall :wx_const.wxID_SELECTALL
  def handle_event(menu_event(@id_selectall), s) do
    :wxStyledTextCtrl.selectAll R.wx_state(s, :textctrl)
    {:noreply, s}
  end
  @edit_insertdatetime R.menu_edit_insertdatetime()
  def handle_event(menu_event(@edit_insertdatetime), s) do
    ts = :os.timestamp()
    {{year, month, day}, {hour, minute, _}} = :calendar.now_to_local_time ts
    date_time = :io_lib.format("~B-~2..0B-~2..0B ~2..0B:~2..0B", [year, month, day, hour, minute])
    :wxStyledTextCtrl.addText R.wx_state(s, :textctrl), date_time
    {:noreply, s}
  end
  @format_wordwrap R.menu_format_wordwrap()
  def handle_event(menu_event(@format_wordwrap, value), s) do
    menu = R.wx_state s, :menu
    statusbar = R.wx_state s, :statusbar
    textctrl = R.wx_state s, :textctrl
    case value do
      0 ->
        :wxMenuBar.enable menu, R.menu_view_statusbar, true
        :wxMenuBar.enable menu, R.menu_edit_goto, true

        StatusBar.set_visible statusbar, :wxMenuBar.isChecked(menu, R.menu_view_statusbar)

        Util.refresh_scroll_width textctrl
        :wxStyledTextCtrl.setWrapMode textctrl, 0
      1 ->
        :wxMenuBar.enable menu, R.menu_view_statusbar, false
        :wxMenuBar.enable menu, R.menu_edit_goto, false

        StatusBar.set_visible statusbar, false

        :wxStyledTextCtrl.setWrapMode textctrl, 1
    end
    {:noreply, s}
  end
  @format_fontselect R.menu_format_fontselect()
  def handle_event(menu_event(@format_fontselect), s) do
    old_font = R.wx_state s, :font
    case Font.show_select_dialog R.wx_state(s, :frame), old_font do
      ^old_font -> {:noreply, s}
      new_font ->
        :wxStyledTextCtrl.styleSetFont R.wx_state(s, :textctrl),
                                       :wx_const.wxSTC_STYLE_DEFAULT,
                                       new_font
        :wxStyledTextCtrl.styleClearAll R.wx_state(s, :textctrl)
        Font.destroy old_font
        Util.refresh_scroll_width R.wx_state(s, :textctrl)
        {:noreply, R.wx_state(s, font: new_font)}
    end
  end
  @view_statusbar R.menu_view_statusbar()
  def handle_event(menu_event(@view_statusbar, enabled), s) do
    StatusBar.set_visible R.wx_state(s, :statusbar), enabled != 0
    {:noreply, s}
  end
  @view_help R.menu_help_viewhelp()
  def handle_event(menu_event(@view_help), s) do
    open_help()
    {:noreply, s}
  end
  @id_about :wx_const.wxID_ABOUT
  def handle_event(menu_event(@id_about), s) do
    message = "#{R.app_name} Version #{Util.get_version}\nA Notepad clone in Elixir"
    dialog = :wxMessageDialog.new R.wx_state(s, :frame), message,
                                  caption: "About #{R.app_name}",
                                  style: :wx_const.wxICON_INFORMATION
    :wxMessageDialog.showModal dialog
    :wxMessageDialog.destroy dialog
    {:noreply, s}
  end
  def handle_event(wx(event: R.wxFindDialogEvent_ex(type: :close)), s) do
    {:noreply, R.wx_state(s, fr_dialog: :undefined)}
  end
  def handle_event(wx(event: R.wxFindDialogEvent_ex(type: t)), s)
  when t in ~w(find find_next)a do
    Text.search R.wx_state(s, :textctrl), R.wx_state(s, :fr_data)
    {:noreply, s}
  end
  def handle_event(wx(event: R.wxFindDialogEvent_ex(type: :replace) = e), s) do
    textctrl = R.wx_state s, :textctrl
    replace_to = R.wxFindDialogEvent_ex e, :replace_string
    Text.replace textctrl, R.wx_state(s, :fr_data), replace_to
    Text.search textctrl, R.wx_state(s, :fr_data)
    {:noreply, s}
  end
  def handle_event(wx(event: R.wxFindDialogEvent_ex(type: :replace_all) = e), s) do
    textctrl = R.wx_state s, :textctrl
    R.wxFindDialogEvent_ex(find_string: search_string,
                           replace_string: replace_to, flags: flags) = e
    Text.replace_all textctrl, search_string, replace_to, flags
    {:noreply, s}
  end
  def handle_event(wx(event: wxKey(type: :key_up, keyCode: key)), s) do
    if key === :wx_const.wxk_F1, do: open_help()
    {:noreply, s}
  end
  def handle_event(event, s) do
    IO.puts "Unhandled Event: #{event}"
    {:noreply, s}
  end

  @spec handle_call(any(), any(), state()) :: {:noreply, state()} | {:reply, :ok, state()}
  def handle_call(:noreply, _from, state), do: {:noreply, state}
  def handle_call(request, _from, state) do
    IO.puts "Unhandled Call: #{request}"
    {:reply, :ok, state}
  end

  @spec handle_cast(any(), state()) :: {:noreply, state()}
  def handle_cast(request, state) do
    IO.puts "Unhandled Cast: #{request}"
    {:noreply, state}
  end

  @spec handle_info(any(), state()) :: {:noreply, state()}
  def handle_info({:open_on_init, filename}, s) do
    case F.ensure_file filename do
      {:yes, name} ->
        case F.load_buffer R.wx_state(s, :textctrl), name do
          :ok ->
            set_window_title R.wx_state(s, :frame), name
            {:noreplay, R.wx_state(s, filename: name)}
          :error ->
            {:noreply, s}
        end
      :no -> {:noreply, s}
    end
  end
  def handle_info(info, state) do
    IO.puts "Unhandled Info: #{info}"
    {:noreply, state}
  end

  @spec terminate(any(), state()) :: :ok
  def terminate(_reason, s) do
    c = R.config window: config_save(s),
                 word_wrap: :wxMenuBar.isChecked(R.wx_state(s, :menu), R.menu_format_wordwrap),
                 status_bar: :wxMenuBar.isChecked(R.wx_state(s, :menu), R.menu_view_statusbar),
                 font: Font.config_save(R.wx_state(s, :font))

    Config.save c

    :wxFrame.destroy R.wx_state(s, :frame)

    Print.destroy R.wx_state(s, :print)
    Font.destroy R.wx_state(s, :font)

    :wx.destroy()
    :ok
  end

  @spec code_change(any(), state(), any()) :: {:ok, state()}
  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  @spec clear_fr_data(state()) :: :ok
  defp clear_fr_data(s) do
    case R.wx_state(s, :fr_data) do
      frdata when is_missing frdata -> :ok
      frdata -> :wxFindReplaceData.destroy frdata
    end
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
  defp get_find_string(frdata) when is_missing(frdata), do: ""
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
