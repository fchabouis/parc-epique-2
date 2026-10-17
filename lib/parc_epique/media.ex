defmodule ParcEpique.Media do
  @moduledoc """
  Image helpers for photos.
  """

  # Same rule as the old Firebase function: fit in 400x400, never enlarge.
  @thumbnail_size 400

  @doc """
  Writes a JPEG thumbnail of `source` to `destination` (which must end in
  `.jpg`), orientation fixed
  from EXIF and metadata (including GPS position) removed.
  """
  def write_thumbnail(source, destination) do
    with {:ok, thumbnail} <-
           Image.thumbnail(source, @thumbnail_size, resize: :down, autorotate: true),
         :ok <- File.mkdir_p(Path.dirname(destination)),
         {:ok, _} <- Image.write(thumbnail, destination, strip_metadata: true) do
      :ok
    end
  end

  @doc """
  Guesses an image file extension from its first bytes, or `nil`.
  """
  def extension(path) do
    case File.open(path, [:read, :binary], &IO.binread(&1, 12)) do
      {:ok, <<0xFF, 0xD8, 0xFF, _::binary>>} ->
        ".jpg"

      {:ok, <<0x89, "PNG", _::binary>>} ->
        ".png"

      {:ok, <<"RIFF", _::binary-size(4), "WEBP">>} ->
        ".webp"

      {:ok, <<"GIF8", _::binary>>} ->
        ".gif"

      {:ok, <<_::binary-size(4), "ftyp", brand::binary-size(4)>>}
      when brand in ~w(heic heix mif1) ->
        ".heic"

      _ ->
        nil
    end
  end
end
