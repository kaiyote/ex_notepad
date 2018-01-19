defmodule ExNotepad.Supervisor do
  @moduledoc false

  use Supervisor

  @spec start_link() :: {:ok, pid()} | :ignore | {:error, any()}
  def start_link, do: Supervisor.start_link __MODULE__, __MODULE__, []

  @spec init([]) :: {:ok, {:supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init([]) do
    sup_flags = %{strategy: :one_for_one, intensity: 0, period: 5}
    a_child = %{id: ExNotepad, start: {ExNotepad, :start_link, []}}

    {:ok, {sup_flags, [a_child]}}
  end
end
