defmodule ParcEpique.Storage do
  @moduledoc """
  File storage for uploaded photos, on the local disk.

  Files are addressed by a key such as `photos/42/photo.jpg`, stored under the
  configured root and served at `/uploads/<key>`.

      config :parc_epique, ParcEpique.Storage, root: "/var/lib/parc_epique/uploads"
  """

  def root, do: Application.fetch_env!(:parc_epique, __MODULE__)[:root]

  def path(key), do: Path.join(root(), safe_key!(key))

  def url(key), do: "/uploads/" <> safe_key!(key)

  def exists?(key), do: File.regular?(path(key))

  @doc "Copies the file at `source` to `key`."
  def put_file(source, key) do
    destination = path(key)

    with :ok <- File.mkdir_p(Path.dirname(destination)) do
      File.cp(source, destination)
    end
  end

  defp safe_key!(key) do
    if key == "" or Path.type(key) != :relative or ".." in Path.split(key) do
      raise ArgumentError, "invalid storage key: #{inspect(key)}"
    end

    key
  end
end
