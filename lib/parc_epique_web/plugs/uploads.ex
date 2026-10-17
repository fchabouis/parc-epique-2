defmodule ParcEpiqueWeb.Plugs.Uploads do
  @moduledoc """
  Serves stored files (`ParcEpique.Storage`) at `/uploads`.

  The storage root is read at runtime, so it can come from `config/runtime.exs`.
  """
  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{path_info: ["uploads" | _]} = conn, _opts) do
    opts =
      Plug.Static.init(
        at: "/uploads",
        from: ParcEpique.Storage.root(),
        cache_control_for_etags: "public, max-age=604800"
      )

    Plug.Static.call(conn, opts)
  end

  def call(conn, _opts), do: conn
end
