defmodule ExNotepad.Application do
  @moduledoc false

  use Application

  @spec start(Application.start_type(), any()) :: {:ok, pid()}
                                                | {:ok, pid(), any()}
                                                | {:error, any()}
  def start(_type, _args), do: ExNotepad.Supervisor.start_link()

  @spec stop(any()) :: :ok
  def stop(_state), do: :ok
end
