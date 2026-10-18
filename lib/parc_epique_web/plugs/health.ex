defmodule ParcEpiqueWeb.Plugs.Health do
  @moduledoc """
  `GET /health`, for the container healthcheck and the uptime monitor: 200
  when the database answers, 503 otherwise. It sits ahead of the rest of the
  endpoint so that probes do not fill the logs.
  """
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{request_path: "/health"} = conn, _opts) do
    {status, body} =
      try do
        case Ecto.Adapters.SQL.query(ParcEpique.Repo, "SELECT 1", []) do
          {:ok, _result} -> {200, "ok"}
          {:error, _error} -> {503, "database unavailable"}
        end
      rescue
        _error -> {503, "database unavailable"}
      catch
        :exit, _reason -> {503, "database unavailable"}
      end

    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(status, body)
    |> halt()
  end

  def call(conn, _opts), do: conn
end
