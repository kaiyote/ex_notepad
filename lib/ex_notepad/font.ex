defmodule ExNotepad.Font do
  @moduledoc false

  require ExNotepad.Records
  alias ExNotepad.Records, as: R

  @spec load(R.font() | nil) :: :wxFont.wxFont() | nil
  def load(nil), do: nil
  def load(R.font(name: :undefined)), do: nil
  def load(R.font(name: name, style: style, weight: weight, size: size)) do
    font = :wxFont.new()
    :wxFont.setFaceName font, name
    :wxFont.setStyle font, style
    :wxFont.setWeight font, weight
    :wxFont.setPointSize font, size

    case :wxFont.ok font do
      true -> font
      false ->
        :wxFont.destroy font
        nil
    end
  end

  @spec default_font() :: :wxFont.wxFont()
  def default_font do
    case load default_config() do
      nil -> :wxFont.new 11,
                         :wx_const.wxFONTFAMILY_TELETYPE,
                         :wx_const.wxFONTSTYLE_NORMAL,
                         :wx_const.wxFONTWEIGHT_NORMAL, []
      font -> font
    end
  end

  @spec destroy(nil | :wxFont.wxFont()) :: :ok
  def destroy(nil), do: :ok
  def destroy(font), do: :wxFont.destroy font

  @spec show_select_dialog(:wxWindow.wxWindow(), :wxFont.wxFont()) :: :wxFont.wxFont
  def show_select_dialog(parent, font) do
    font_data = :wxFontData.new()
    :wxFontData.enableEffects font_data, false
    :wxFontData.setInitialFont font_data, font

    dialog = :wxFontDialog.new parent, font_data
    :wxFontData.destroy font_data
    ok = :wx_const.wxID_OK
    cancel = :wx_const.wxID_CANCEL
    try do
      case :wxDialog.showModal dialog do
        ^ok ->
          new_font_data = :wxFontDialog.getFontData dialog
          :wxFontData.getChosenFont new_font_data
        ^cancel -> font
      end
    after
      :wxFontDialog.destroy dialog
    end
  end

  @spec config_save(nil | :wxFont.wxFont()) :: nil | R.font()
  def config_save(nil), do: nil
  def config_save(font) do
    R.font name: :wxFont.getFaceName(font),
           style: :wxFont.getStyle(font),
           weight: :wxFont.getWeight(font),
           size: :wxFont.getPointSize(font)
  end

  @spec config_check(R.font() | nil) :: R.font() | nil
  def config_check(R.font() = f)
    when is_list(R.font(f, :name)) and is_integer(R.font(f, :style))
    and is_integer(R.font(f, :weight)) and is_integer(R.font(f, :size)), do: f
  def config_check(_), do: nil

  @spec default_config() :: R.font()
  defp default_config do
    R.font name: "Consolas",
           style: :wx_const.wxFONTSTYLE_NORMAL,
           weight: :wx_const.wxFONTWEIGHT_NORMAL,
           size: 11
  end
end
