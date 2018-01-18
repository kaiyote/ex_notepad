defmodule ExNotepad.Menu do
  @moduledoc false

  import ExNotepad.Records

  @opaque menu_item_desc :: {integer(), String.t()} |
                          {integer(), String.t(), :check | :disabled} |
                          :separator

  @spec create(:wxFrame.wxFrame()) :: :wxMenuBar.wxMenuBar()
  def create(frame) do
    menu_bar = :wxMenuBar.new()

    file_menu = create_menu [
      {:wx_const.wxID_NEW, "&New\tCtrl+N"},
      {:wx_const.wxID_OPEN, "&Open...\tCtrl+O"},
      {:wx_const.wxID_SAVE, "&Save\tCtrl+S"},
      {:wx_const.wxID_SAVEAS, "Save &As..."},
      :separator,
      {:wx_const.wxID_PAGE_SETUP, "Page Set&up"},
      {:wx_const.wxID_PRINT, "&Print...\tCtl+P"},
      :separator,
      {:wx_const.wxID_EXIT, "E&xit"}
    ]

    edit_menu = create_menu [
      {:wx_const.wxID_UNDO, "&Undo\tCtrl+Z", :disabled},
      :separator,
      {:wx_const.wxID_CUT, "Cu&t\tCtrl+X"},
      {:wx_const.wxID_COPY, "&Copy\tCtrl+C"},
      {:wx_const.wxID_PASTE, "&Paste\tCtrl+V"},
      {:wx_const.wxID_DELETE, "De&lete\t Del", :disabled},
      :separator,
      {:wx_const.wxID_FIND, "&Find...\tCtrl+F"},
      {menu_edit_findnext(), "Find &Next\tF3"},
      {:wx_const.wxID_REPLACE, "&Replace...\tCtrl+H"},
      {menu_edit_goto(), "&Go To...\tCtrl+G"},
      :separator,
      {:wx_const.wxID_SELECTALL, "Select &All\tCtrl+A"},
      {menu_edit_insertdatetime(), "Time/&Date\tF5"}
    ]

    format_menu = create_menu [
      {menu_format_wordwrap(), "&Word Wrap", :check},
      {menu_format_fontselect(), "&Font..."}
    ]

    view_menu = create_menu [
      {menu_view_statusbar(), "&Status Bar", :check}
    ]

    help_menu = create_menu [
      {menu_help_viewhelp(), "View &Help"},
      :separator,
      {:wx_const.wxID_ABOUT, "&About #{app_name()}"}
    ]

    :wxMenuBar.append menu_bar, file_menu, "&File"
    :wxMenuBar.append menu_bar, edit_menu, "&Edit"
    :wxMenuBar.append menu_bar, format_menu, "F&ormat"
    :wxMenuBar.append menu_bar, view_menu, "&View"
    :wxMenuBar.append menu_bar, help_menu, "&Help"

    :wxFrame.setMenuBar frame, menu_bar

    menu_bar
  end

  @spec create_menu(list(menu_item_desc())) :: :wxMenu.wxMenu()
  defp create_menu(items) do
    menu = :wxMenu.new()

    for item <- items, do: append_item menu, item

    menu
  end

  @spec append_item(:wxMenu.wxMenu(), menu_item_desc()) :: :ok | :wx.wx_object()
  defp append_item(menu, {id, text}) do
    item = :wxMenuItem.new id: id, text: text
    :wxMenu.append menu, item
  end
  defp append_item(menu, {id, text, :check}) do
    item = :wxMenuItem.new id: id, text: text, kind: :wx_const.wxITEM_CHECK
    :wxMenu.append menu, item
  end
  defp append_item(menu, {id, text, :disabled}) do
    item = :wxMenuItem.new id: id, text: text
    :wxMenu.append menu, item
    :wxMenuItem.enable item, enable: false
  end
  defp append_item(menu, :separator), do: :wxMenu.appendSeparator menu
end
