defmodule ExNotepad do
  @moduledoc false

  alias ExNotepad.Wx

  @spec main() :: any()
  def main, do: main []

  @spec main(list()) :: any()
  def main([]) do
    Application.load ExNotepad
    case Wx.start_link() do
      {:error, _} = err -> show_error err
      exnotepad -> Wx.wait_forever exnotepad
    end
  end
  def main([filename]) do
    Application.load ExNotepad
    case Wx.start_link filename do
      {:error, _} = err -> show_error err
      exnotepad -> Wx.wait_forever exnotepad
    end
  end
  def main([filename | _]), do: main [filename]

  @spec start_link() :: {:ok, pid(), :wx.wx_object()}
  def start_link do
    case Application.get_env ExNotepad, :file do
      filename when is_binary(filename) and filename != "" -> start_link filename
      _ ->
        case Wx.start_link do
          {:error, _} = e -> e
          wxobject -> {:ok, :wx_object.get_pid(wxobject), wxobject}
        end
    end
  end

  @spec start_link(String.t()) :: {:ok, pid(), :wx.wx_object()}
  def start_link(filename) do
    case Wx.start_link filename do
      {:error, _} = e -> e
      wxobject -> {:ok, :wx_object.get_pid(wxobject), wxobject}
    end
  end

  @spec show_error(any()) :: integer()
  defp show_error(error) do
    :wx.new()
    message = "Something bad happened: #{error}"
    dialog = :wxMessageDialog.new :wx.null(), message,
                                  caption: "Error", style: :wx_const.wxICON_ERROR
    try do
      :wxMessageDialog.showModal dialog
    after
      :wxMessageDialog.destroy dialog
      :wx.destroy()
    end
  end
end
