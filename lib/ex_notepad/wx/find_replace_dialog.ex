defmodule ExNotepad.Wx.FindReplaceDialog do
  @moduledoc false
  @dialyzer {:nowarn_function, 'MACRO-button_clicked': 2}

  require ExNotepad.Records
  alias ExNotepad.Records, as: R

  use Bitwise, only_operators: true

  require Record
  Record.defrecordp :wx, Record.extract(:wx, from_lib: "wx/include/wx.hrl")
  Record.defrecordp :wxCommand, Record.extract(:wxCommand, from_lib: "wx/include/wx.hrl")
  Record.defrecordp :wxClose, Record.extract(:wxClose, from_lib: "wx/include/wx.hrl")
  Record.defrecordp :wxShow, Record.extract(:wxShow, from_lib: "wx/include/wx.hrl")

  @behaviour :wx_object

  @typep window :: :wxWindow.wxWindow()
  @type wx :: wx()

  @spec demo() :: :ok | {:error, any()}
  def demo do
    :wx.new()

    fr_data = :wxFindReplaceData.new()
    :wxFindReplaceData.setFlags fr_data, :wx_const.wxFR_DOWN

    case :wx_object.start __MODULE__, [:wx.null(), fr_data, "Find", 0], [] do
      {:error, _} = err -> err
      object ->
        connect object, :find_dialog_event
        demo_wait_close()
        :wx.destroy()
    end
  end

  @spec new(window(), R.fr_data(), String.t()) :: R.wxFindReplaceDialog_ex()
  def new(parent, fr_data, title), do: new parent, fr_data, title, [{:style, 0}]

  @spec new(window(), R.fr_data(), String.t(), [{:style, integer()}]) :: R.wxFindReplaceDialog_ex()
  def new(parent, fr_data, title, [{:style, style}]) do
    case :wx_object.start __MODULE__, {parent, fr_data, title, style}, [] do
      {:error, _} = err -> err
      object -> object
    end
  end

  @spec connect(R.wxFindReplaceDialog_ex(), :find_dialog_event) :: :ok
  def connect(this, :find_dialog_event) do
    :wx_object.call this, {:connect, :find_dialog_event, self()}
  end

  @spec disconnect(R.wxFindReplaceDialog_ex()) :: :ok
  def disconnect(this), do: :wx_object.call this, {:disconnect, self()}

  @spec demo_wait_close() :: :ok
  defp demo_wait_close do
    receive do
      wx(event: R.wxFindDialogEvent_ex(type: :close)) ->
        IO.puts "Dialog closed"
      wx() = ev ->
        IO.puts "Received Event: #{ev}"
        demo_wait_close()
      other ->
        IO.puts "Received Something else: #{other}"
        demo_wait_close()
    end
  end

  @fr_replacedialog :wx_const.wxFR_REPLACEDIALOG
  @spec init({window(), R.fr_data(), String.t(), integer()}) :: {:wxDialog.wxDialog, R.state()}
  def init({parent, fr_data, title, style}) do
    dialog_size = case style &&& @fr_replacedialog do
      @fr_replacedialog -> {361, 140 + 52}
      _ -> {370, 140}
    end

    dialog = :wxDialog.new parent, -1, title, pos: {1350, 100}, size: dialog_size

    controls = create_controls dialog, style

    set_initial_values controls, fr_data

    connect_events controls

    :wxDialog.show dialog

    {dialog, R.state(parent: parent, controls: controls, frdata: fr_data)}
  end

  defmacrop button_clicked(id) do
    quote do
      wx(id: unquote(id), event: wxCommand(type: :command_button_clicked))
    end
  end

  @spec handle_event(wx(), R.state()) :: {:noreply, R.state()} | {:stop, :normal, R.state()}
  def handle_event(wx(event: wxCommand(type: :command_text_updated) = cmd), s) do
    enable_buttons(R.state(s, :controls), wxCommand(cmd, :cmdString) != "")
    {:noreply, s}
  end
  def handle_event(wx(event: wxCommand(type: :command_text_enter)), s) do
    notify_event :find, R.state(s, :listener), R.state(s, :controls), R.state(s, :frdata)
    {:noreply, s}
  end
  @wx_find :wx_const.wxID_FIND
  def handle_event(button_clicked(@wx_find), s) do
    notify_event :find, R.state(s, :listener), R.state(s, :controls), R.state(s, :frdata)
    {:noreply, s}
  end
  @wx_replace :wx_const.wxID_REPLACE
  def handle_event(button_clicked(@wx_replace), s) do
    notify_event :replace, R.state(s, :listener), R.state(s, :controls), R.state(s, :frdata)
    {:noreply, s}
  end
  @wx_replace_all :wx_const.wxID_REPLACE_ALL
  def handle_event(button_clicked(@wx_replace_all), s) do
    notify_event :replace_all, R.state(s, :listener), R.state(s, :controls), R.state(s, :frdata)
    {:noreply, s}
  end
  @wx_cancel :wx_const.wxID_CANCEL
  def handle_event(button_clicked(@wx_cancel), s) do
    {:stop, :normal, s}
  end
  def handle_event(wx(event: wxClose()), s) do
    {:stop, :normal, s}
  end
  def handle_event(wx(event: wxShow(show: show)), s) do
    case show do
      false -> {:stop, :normal, s}
      true -> {:noreply, s}
    end
  end
  def handle_event(event, state) do
    IO.puts "#{__MODULE__} Unhandled Event: #{event}"
    {:noreply, state}
  end

  @spec handle_call(any(), any(), R.state()) :: {:reply, :ok, R.state()}
  def handle_call({:connect, _event_type, pid}, _from, s) do
    {:reply, :ok, R.state(s, listener: pid)}
  end
  def handle_call(request, _from, state) do
    IO.puts "Unhandled Call: #{request}"
    {:reply, :ok, state}
  end

  @spec handle_cast(any(), R.state()) :: {:noreply, R.state()}
  def handle_cast(request, state) do
    IO.puts "Unhandled Cast: #{request}"
    {:noreply, state}
  end

  @spec handle_info(any(), R.state()) :: {:noreply, R.state()}
  def handle_info(info, state) do
    IO.puts "Unhandled Info: #{info}"
    {:noreply, state}
  end

  @spec terminate(any(), R.state()) :: :ok
  def terminate(_reason, s) do
    notify_event :close, R.state(s, :listener), R.state(s, :controls), R.state(s, :frdata)
    :wxDialog.destroy R.ctrl R.state(s, :controls), :dialog
    :ok
  end

  @spec code_change(any(), R.state(), any()) :: {:ok, R.state()}
  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  @wx_replacedialog :wx_const.wxFR_REPLACEDIALOG
  @spec create_controls(:wxDialog.wxDialog, integer()) :: R.ctrl()
  defp create_controls(dialog, style) when (style &&& @wx_replacedialog) != 0 do
    main_panel = :wxPanel.new dialog

    find_box = :wxTextCtrl.new main_panel,
                               :wx_const.wxID_ANY,
                               pos: {81, 11},
                               size: {171, 20},
                               style: :wx_const.wxTE_PROCESS_ENTER

    replace_box = :wxTextCtrl.new main_panel,
                                  :wx_const.wxID_ANY,
                                  pos: {81, 39},
                                  size: {171, 20},
                                  style: :wx_const.wxTE_PROCESS_ENTER

    find_next_button = :wxButton.new main_panel,
                                     :wx_const.wxID_FIND,
                                     label: "&Find Next",
                                     pos: {261, 7},
                                     size: {75, 23}

    replace_button = :wxButton.new main_panel,
                                   :wx_const.wxID_REPLACE,
                                   label: "&Replace",
                                   pos: {261, 34},
                                   size: {75, 23}

    replace_all_button = :wxButton.new main_panel,
                                   :wx_const.wxID_REPLACE_ALL,
                                   label: "&Replace All",
                                   pos: {261, 62},
                                   size: {75, 23}

    cancel_button = :wxButton.new main_panel,
                                   :wx_const.wxID_CANCEL,
                                   label: "Cancel",
                                   pos: {261, 89},
                                   size: {75, 23}

    whole_word = case style &&& :wx_const.wxFR_NOWHOLEWORD do
      0 -> :wxCheckBox.new main_panel, :wx_const.wxID_ANY, "Match &whole word only", pos: {8, 77}
      _ -> :undefined
    end

    match_case = case style &&& :wx_const.wxFR_NOMATCHCASE do
      0 -> :wxCheckBox.new main_panel, :wx_const.wxID_ANY, "Match &case", pos: {8, 103}
      _ -> :undefined
    end

    R.ctrl dialog: dialog, main_panel: main_panel, find_box: find_box, replace_box: replace_box,
           find_next_button: find_next_button, replace_button: replace_button,
           replace_all_button: replace_all_button, cancel_button: cancel_button,
           whole_word_checkbox: whole_word, match_case_checkbox: match_case
  end
  defp create_controls(dialog, style) do
    main_panel = :wxPanel.new dialog

    find_box = :wxTextCtrl.new main_panel,
                               :wx_const.wxID_ANY,
                               pos: {71, 11},
                               size: {192, 20},
                               style: :wx_const.wxTE_PROCESS_ENTER

    find_next_button = :wxButton.new main_panel,
                                     :wx_const.wxID_FIND,
                                     label: "&Find Next",
                                     pos: {273, 8},
                                     size: {75, 23}

    cancel_button = :wxButton.new main_panel,
                                  :wx_const.wxID_CANCEL,
                                  label: "Cancel",
                                  pos: {273, 37},
                                  size: {75, 23}

    whole_word = case style &&& :wx_const.wxFR_NOWHOLEWORD do
      0 -> :wxCheckBox.new main_panel, :wx_const.wxID_ANY, "Match &whole word only", pos: {6, 44}
      _ -> :undefined
    end

    match_case = case style &&& :wx_const.wxFR_NOMATCHCASE do
      0 -> :wxCheckBox.new main_panel, :wx_const.wxID_ANY, "Match &case", pos: {6, 70}
      _ -> :undefined
    end

    {up_radio_button, down_radio_button} = case style &&& :wx_const.wxFR_NOUPDOWN do
      0 ->
        {
          :wxRadioButton.new(main_panel, :wx_const.wxID_ANY, "&Up", pos: {167, 64}),
          :wxRadioButton.new(main_panel, :wx_const.wxID_ANY, "&Down", pos: {207, 64})
        }
      _ -> {:undefined, :undefined}
    end

    R.ctrl dialog: dialog, main_panel: main_panel, find_box: find_box,
           find_next_button: find_next_button, cancel_button: cancel_button,
           whole_word_checkbox: whole_word, match_case_checkbox: match_case,
           up_radio: up_radio_button, down_radio: down_radio_button
  end

  @spec enable_buttons(R.ctrl(), boolean()) :: :ok
  defp enable_buttons(controls, enable) do
    :wxButton.enable R.ctrl(controls, :find_next_button), enable: enable

    case {R.ctrl(controls, :replace_button), R.ctrl(controls, :replace_all_button)} do
      {:undefined, :undefined} -> :ok
      {b1, b2} ->
        :wxButton.enable b1, enable: enable
        :wxButton.enable b2, enable: enable
    end
  end

  @spec set_initial_values(R.ctrl(), R.fr_data()) :: :ok
  defp set_initial_values(controls, fr_data) do
    :wxButton.setDefault R.ctrl(controls, :find_next_button)

    case :wxFindReplaceData.getFindString fr_data do
      [] -> enable_buttons controls, false
      value -> :wxTextCtrl.changeValue R.ctrl(controls, :find_box), value
    end

    replace_box = R.ctrl controls, :replace_box
    if replace_box != :undefined, do:
      :wxTextCtrl.changeValue replace_box, :wxFindReplaceData.getReplaceString fr_data

    flags = :wxFindReplaceData.getFlags fr_data

    up_radio = R.ctrl controls, :up_radio
    if up_radio != :undefined do
      case flags &&& :wx_const.wxFR_DOWN do
        0 -> :wxRadioButton.setValue up_radio, true
        _ -> :wxRadioButton.setValue R.ctrl(controls, :down_radio), true
      end
    end

    whole_word_checkbox = R.ctrl controls, :whole_word_checkbox
    if whole_word_checkbox != :undefined, do:
      :wxCheckBox.setValue whole_word_checkbox,
                           (flags &&& :wx_const.wxFR_WHOLEWORD) === :wx_const.wxFR_WHOLEWORD

    match_case_checkbox = R.ctrl controls, :match_case_checkbox
    if match_case_checkbox != :undefined, do:
      :wxCheckBox.setValue match_case_checkbox,
                          (flags &&& :wx_const.wxFR_MATCHCASE) === :wx_const.wxFR_MATCHCASE
  end

  @spec connect_events(R.ctrl()) :: :ok
  defp connect_events(R.ctrl() = c) do
    :wxTextCtrl.connect R.ctrl(c, :find_box), :command_text_updated

    :wxTextCtrl.connect R.ctrl(c, :find_box), :command_text_enter

    :wxButton.connect R.ctrl(c, :find_next_button), :command_button_clicked
    :wxButton.connect R.ctrl(c, :cancel_button), :command_button_clicked

    replace_box = R.ctrl c, :replace_box
    unless replace_box == :undefined do
      :wxTextCtrl.connect replace_box, :command_text_enter
      :wxButton.connect R.ctrl(c, :replace_button), :command_button_clicked
      :wxButton.connect R.ctrl(c, :replace_all_button), :command_button_clicked
    end

    :wxDialog.connect R.ctrl(c, :dialog), :show

    :wxDialog.connect R.ctrl(c, :dialog), :close_window
  end

  @spec notify_event(R.fr_event(), R.listener(), R.ctrl(), R.fr_data) :: :ok
  defp notify_event(_, _, _, _) do
    :ok
  end
end
