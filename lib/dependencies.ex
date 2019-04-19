defmodule Dependencies do
  @moduledoc """
  Documentation for Dependencies.
  """
  alias Tentacat.Client
  alias Tentacat.Contents
  alias ExAws.S3

  @github_client Client.new(
                   %{access_token: ""},
                   "https://api.github.com"
                 )
  @bucket Application.get_env(:dependencies, :s3)[:bucket]
  @filename Application.get_env(:dependencies, :s3)[:filename]
  @git_repository %Git.Repository{path: "./"}

  # def run(app1, app2) do
  #   app1_mapping =
  #     Contents.find(@github_client, "primait", app1, "mix.lock")
  #     |> deps_mapping(app1)
  #
  #   app2_mapping =
  #     Contents.find(@github_client, "primait", app2, "mix.lock")
  #     |> deps_mapping(app2)
  #
  #   Map.merge(app1_mapping, app2_mapping, fn _k, v1, v2 -> v1 ++ v2 end)
  #   |> Jason.encode!()
  # end

  def run(app_name) do
    mapping =
      Contents.find(@github_client, "primait", app_name, "mix.lock")
      |> deps_mapping(app_name)

    download()
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

  def download() do
    S3.get_object(@bucket, @filename)
    |> ExAws.request!()
    |> decode()
  end

  def decode(%{body: body}) do
    Jason.decode!(body)
  end

  def merge(source, new_mapping) do
    Map.merge(source, new_mapping, fn _k, v1, v2 -> Map.merge(v1, v2) end)
    |> Jason.encode!()
  end

  def save(mapping) do
    # S3.put_object(@bucket, @filename, mapping)
    # |> ExAws.request!()

    file = File.open!("./README.md", [:write])
    IO.binwrite(file, Jason.Formatter.pretty_print(mapping))
    File.close(file)

    Git.add!(@git_repository, "./README.md")
    Git.commit!(@git_repository, "Update dependencies")
    Git.push!(@git_repository)
  end
end
