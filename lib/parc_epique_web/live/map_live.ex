defmodule ParcEpiqueWeb.MapLive do
  @moduledoc """
  Home page: the map of playgrounds.

  The `Map` JS hook (assets/js/hooks/map.js) sends the visible bounds with a
  "bounds" event; the playgrounds inside are pushed back as "playgrounds".
  """
  use ParcEpiqueWeb, :live_view

  alias ParcEpique.Playgrounds

  @limit 3000

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Playground map"), truncated: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      <div class="relative">
        <div
          id="map"
          phx-hook="Map"
          phx-update="ignore"
          data-style-url={Application.fetch_env!(:parc_epique, :map_style_url)}
          data-locate-label={gettext("Show my position")}
          class="h-[calc(100dvh-4rem)] w-full"
        >
        </div>
        <p
          :if={@truncated}
          class="absolute bottom-6 left-1/2 z-[1000] -translate-x-1/2 rounded-full bg-base-100 px-4 py-2 text-sm shadow"
        >
          {gettext("Zoom in to see all the playgrounds")}
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("bounds", params, socket) do
    case parse_bounds(params) do
      {:ok, bounds} ->
        {playgrounds, truncated} = Playgrounds.list_in_bounds(bounds, limit: @limit)

        {:noreply,
         socket
         |> assign(truncated: truncated)
         |> push_event("playgrounds", %{playgrounds: Enum.map(playgrounds, &marker/1)})}

      :error ->
        {:noreply, socket}
    end
  end

  defp marker(%{
         id: id,
         name: name,
         reviewed: reviewed,
         location: %Geo.Point{coordinates: {lng, lat}}
       }) do
    %{id: id, lat: lat, lng: lng, name: name || gettext("Playground"), reviewed: reviewed}
  end

  @doc false
  def parse_bounds(%{"south" => s, "west" => w, "north" => n, "east" => e})
      when is_number(s) and is_number(w) and is_number(n) and is_number(e) do
    {:ok,
     %{
       south: clamp(s, -90, 90),
       north: clamp(n, -90, 90),
       west: clamp(w, -180, 180),
       east: clamp(e, -180, 180)
     }}
  end

  def parse_bounds(_params), do: :error

  defp clamp(value, lo, hi), do: value |> max(lo) |> min(hi) |> Kernel.*(1.0)
end
