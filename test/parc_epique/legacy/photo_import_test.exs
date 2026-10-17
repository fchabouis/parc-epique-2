defmodule ParcEpique.Legacy.PhotoImportTest do
  # Not async: writes to the shared test storage directory.
  use ParcEpique.DataCase

  alias ParcEpique.Legacy.PhotoImport
  alias ParcEpique.Playgrounds.{Photo, Playground}
  alias ParcEpique.Storage

  @bucket "https://storage.googleapis.com/aires-de-jeux-e8525.appspot.com"

  setup do
    File.rm_rf!(Storage.root())
    export = Path.join(System.tmp_dir!(), "photo_export_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(export) end)

    playground =
      Repo.insert!(
        Playground.changeset(%Playground{}, %{
          legacy_key: "node-1031945363",
          location: Playground.point(50.638265, 3.0809135)
        })
      )

    %{export: export, playground: playground}
  end

  test "copies photos and thumbnails and points the rows at them", ctx do
    name = "node-1031945363_uid-a_1600000000000"
    write_image(ctx.export, "node-1031945363/#{name}", 800, 600)
    write_image(ctx.export, "node-1031945363/thumb_#{name}", 400, 300)
    photo = insert_photo(ctx.playground, name, encoded: true)

    report = PhotoImport.run(ctx.export)

    assert %{imported: 1, thumbnails_generated: 0, missing: [], failed: [], unused_files: []} =
             report

    photo = Repo.reload!(photo)
    assert photo.path == "photos/#{ctx.playground.id}/#{name}.jpg"
    assert photo.thumbnail_path == "photos/#{ctx.playground.id}/thumb_#{name}.jpg"
    assert Storage.exists?(photo.path)
    assert Storage.exists?(photo.thumbnail_path)
  end

  test "regenerates a missing thumbnail", ctx do
    name = "node-1031945363_uid-a_1600000000001"
    write_image(ctx.export, "node-1031945363/#{name}", 1200, 900)
    write_image(ctx.export, "node-1031945363/stray_file", 10, 10)
    photo = insert_photo(ctx.playground, name, thumbnail: false)

    assert %{imported: 1, thumbnails_generated: 1, unused_files: ["stray_file"]} =
             PhotoImport.run(ctx.export)

    thumbnail = Image.open!(Storage.path(Repo.reload!(photo).thumbnail_path))
    assert {Image.width(thumbnail), Image.height(thumbnail)} == {400, 300}
  end

  test "reports photos missing from the export and can be re-run", ctx do
    name = "node-1031945363_uid-a_1600000000002"
    write_image(ctx.export, "node-1031945363/#{name}", 100, 100)
    insert_photo(ctx.playground, name, thumbnail: false)
    missing = insert_photo(ctx.playground, "node-1031945363_uid-b_1", thumbnail: false)

    assert %{imported: 1, missing: [legacy_key]} = PhotoImport.run(ctx.export)
    assert legacy_key == missing.legacy_key

    # Imported photos are skipped on the next run.
    assert %{imported: 0, missing: [^legacy_key]} = PhotoImport.run(ctx.export)
  end

  test "ignores unfinished downloads", ctx do
    name = "node-1031945363_uid-a_1600000000003"
    write_image(ctx.export, "node-1031945363/#{name}_.gstmp", 100, 100)
    insert_photo(ctx.playground, name, thumbnail: false)

    assert %{imported: 0, missing: [_], partial_downloads: [partial]} =
             PhotoImport.run(ctx.export)

    assert partial == "#{name}_.gstmp"
  end

  test "file names are read from plain and encoded URLs" do
    assert PhotoImport.file_name("#{@bucket}/photos/node-1/node-1_uid_2") == "node-1_uid_2"

    assert PhotoImport.file_name("#{@bucket}/photos%2Fnode-1%2Fthumb_node-1_uid_2") ==
             "thumb_node-1_uid_2"
  end

  defp insert_photo(playground, name, opts) do
    url =
      if opts[:encoded],
        do: &"#{@bucket}/photos%2F#{playground.legacy_key}%2F#{&1}",
        else: &"#{@bucket}/photos/#{playground.legacy_key}/#{&1}"

    Repo.insert!(
      Photo.changeset(%Photo{}, %{
        playground_id: playground.id,
        legacy_key: "#{playground.legacy_key}/#{name}",
        path: url.(name),
        thumbnail_path: if(Keyword.get(opts, :thumbnail, true), do: url.("thumb_" <> name))
      })
    )
  end

  # Writes a JPEG without extension, like the files exported from Firebase.
  defp write_image(dir, relative_path, width, height) do
    path = Path.join(dir, relative_path)
    File.mkdir_p!(Path.dirname(path))
    Image.write!(Image.new!(width, height, color: :green), path <> ".jpg")
    File.rename!(path <> ".jpg", path)
    path
  end
end
