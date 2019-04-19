defmodule Dependencies do
  @moduledoc """
  Documentation for Dependencies.
  """
  alias Tentacat.Client
  alias Tentacat.Contents
  alias ExAws.S3

  @github_client Client.new(
                   %{access_token: System.get_env("GITHUB_TOKEN")},
                   "https://api.github.com"
                 )
  @filename "./README.md"
  @git_repository %Git.Repository{path: "./"}

  def run(app_name) do
    mapping =
      Contents.find(@github_client, "primait", app_name, "mix.lock")
      |> deps_mapping(app_name)

    load()
    |> merge(mapping)
    |> save()
  end

  def deps_mapping({_, %{"content" => content}, _}, app_name) do
    Base.decode64!(content, ignore: :whitespace)
    |> Code.eval_string()
    |> Kernel.elem(0)
    |> Enum.map(fn {k, v} -> %{"#{k}" => %{app_name => "#{Kernel.elem(v, 2)}"}} end)
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  def load() do
    file = File.open!(@filename, [:read])
    raw = IO.binread(file, :all)
    File.close(file)

    raw
    |> String.replace("```", "")
    |> Jason.decode!()
  end

  def merge(source, new_mapping) do
    Map.merge(source, new_mapping, fn _k, v1, v2 -> Map.merge(v1, v2) end)
    |> Jason.encode!()
  end

  def save(mapping) do
    file = File.open!(@filename, [:write])
    IO.binwrite(file, prettify(mapping))
    File.close(file)

    # Git.add!(@git_repository, @filename)
    # Git.commit!(@git_repository, ["-m", "Update dependencies"])
    # Git.push!(@git_repository)
  end

  def prettify(raw_json) do
    "```" <> Jason.Formatter.pretty_print(raw_json) <> "```"
  end
end
