defmodule Polyecto.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/mindreframer/polyecto"

  def project do
    [
      app: :polyecto,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      preferred_cli_env: [test: :test],

      # Hex
      description: description(),
      package: package(),

      # Docs
      name: "PolyEcto",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.10"},
      {:ecto_sql, "~> 3.10", only: :test},
      {:postgrex, "~> 0.17", only: :test},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp description do
    """
    A generic, configurable library for polymorphic associations in Ecto schemas.
    Provides clean, efficient "belongs to any" and "has many polymorphic" relationships
    with batch loading and no N+1 queries.
    """
  end

  defp package do
    [
      name: "polyecto",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      maintainers: ["Roman Heinrich"]
    ]
  end

  defp docs do
    [
      main: "PolyEcto",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "lib/polyecto/README.md": [title: "Comprehensive Guide"]
      ],
      groups_for_extras: [
        Guides: ~r/README\.md/
      ]
    ]
  end
end
