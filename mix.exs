defmodule ExNotepad.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_notepad,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:wx]],
      escript: [main_module: ExNotepad, app: nil]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExNotepad.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 0.8.10", only: ~w|dev test|a, runtime: false},
      {:dialyxir, "~> 0.5.1", only: ~w|dev test|a, runtime: false},
      {:wx_utils, "~> 0.0.2"}
    ]
  end
end
