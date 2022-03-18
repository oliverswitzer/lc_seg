defmodule LcSeg.MixProject do
  use Mix.Project

  def project do
    [
      app: :lc_seg,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib", "test/support/mrt_transcript_parser.ex"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:statistex, "~> 1.0"},
      {:euclid, "~> 0.2.5", only: :test},
      {:floki, "~> 0.32.0", only: [:dev, :test]},
      {:uuid, "~> 1.1.8"},
      {:kino, "~> 0.5.0"},
      {:vega_lite, "~> 0.1.0", only: [:dev]},
      {:similarity, "~> 0.2.1"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end
end
