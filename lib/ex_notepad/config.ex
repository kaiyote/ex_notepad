defmodule ExNotepad.Config do
  @moduledoc false

  require ExNotepad.Records
  alias ExNotepad.Records, as: R
  alias ExNotepad.{Font, Wx}

  @spec load() :: R.config()
  def load do
    filename = Path.join config_dir(), R.config_file()
    case :file.consult filename do
      {:ok, [R.config() = config]} -> config_check config
      _ -> R.config()
    end
  end

  @spec save(R.config()) :: :ok
  def save(R.config() = c) do
    filename = Path.join config_dir(), R.config_file()
    case :filelib.ensure_dir filename do
      :ok -> File.write! filename, :io_lib.format("~p.\n", [c])
      {:error, _} -> :ok
    end
  end

  @spec config_dir() :: :file.filename_all()
  defp config_dir, do: :filename.basedir :user_config, R.app_name

  @spec config_check(R.config()) :: R.config()
  defp config_check(R.config() = c)
  when is_boolean(R.config(c, :word_wrap)) and is_boolean(R.config(c, :status_bar)) do

    R.config c, window: Wx.config_check(R.config(c, :window)),
                font: Font.config_check(R.config(c, :font))
  end
  defp config_check(_), do: R.config()
end
