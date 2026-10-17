defmodule ParcEpiqueWeb.MapLive do
  @moduledoc """
  Home page: the map of playgrounds.

  The `Map` JS hook (assets/js/hooks/map.js) sends the visible bounds with a
  "bounds" event; the playgrounds inside are pushed back as "playgrounds".

  At `/:locale/aires/:id` the playground sheet is open next to the map. It is
  part of the server-rendered page, so each playground has a URL that can be
  shared and crawled. Clicking a marker sends "open", which patches the URL.
  """
  use ParcEpiqueWeb, :live_view

  alias ParcEpique.Playgrounds
  alias ParcEpiqueWeb.PlaygroundComponents

  @limit 3000

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, truncated: false, photo: nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    playground = Playgrounds.get_visible_playground!(parse_id!(id))

    {:noreply,
     socket
     |> assign(
       playground: playground,
       ratings: Playgrounds.average_ratings(playground.reviews),
       photo: nil,
       page_title: PlaygroundComponents.playground_name(playground)
     )
     |> push_event("focus", %{
       id: playground.id,
       lat: PlaygroundComponents.lat(playground),
       lng: PlaygroundComponents.lng(playground)
     })}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, playground: nil, photo: nil, page_title: gettext("Playground map"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      <div class="relative flex h-[calc(100dvh-4rem)]">
        <div
          id="map"
          phx-hook="Map"
          phx-update="ignore"
          data-locate-label={gettext("Show my position")}
          data-focus-lat={@playground && PlaygroundComponents.lat(@playground)}
          data-focus-lng={@playground && PlaygroundComponents.lng(@playground)}
          class="h-full min-w-0 flex-1"
        >
        </div>
        <p
          :if={@truncated}
          class="absolute bottom-6 left-1/2 z-[1000] -translate-x-1/2 rounded-full bg-base-100 px-4 py-2 text-sm shadow"
        >
          {gettext("Zoom in to see all the playgrounds")}
        </p>
        <aside
          :if={@playground}
          id="playground-sheet"
          class="absolute inset-x-0 bottom-0 z-[1000] max-h-[60%] overflow-y-auto rounded-t-2xl bg-base-100 shadow-xl md:static md:max-h-none md:w-[28rem] md:shrink-0 md:rounded-none md:border-l md:border-base-300 md:shadow-none"
        >
          <PlaygroundComponents.playground_sheet
            playground={@playground}
            ratings={@ratings}
            close={~p"/#{@locale}"}
          />
        </aside>
      </div>
      <PlaygroundComponents.photo_modal :if={@photo} photo={@photo} />
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

  def handle_event("open", %{"id" => id}, socket) when is_integer(id) do
    {:noreply, push_patch(socket, to: ~p"/#{socket.assigns.locale}/aires/#{id}")}
  end

  def handle_event("show_photo", %{"id" => id}, %{assigns: %{playground: %{} = p}} = socket) do
    {:noreply, assign(socket, photo: Enum.find(p.photos, &(to_string(&1.id) == id)))}
  end

  def handle_event("show_photo", _params, socket), do: {:noreply, socket}

  def handle_event("hide_photo", _params, socket) do
    {:noreply, assign(socket, photo: nil)}
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

  defp parse_id!(id) do
    case Integer.parse(id) do
      {id, ""} when id > 0 -> id
      _ -> raise Ecto.NoResultsError, queryable: ParcEpique.Playgrounds.Playground
    end
  end

  defp clamp(value, lo, hi), do: value |> max(lo) |> min(hi) |> Kernel.*(1.0)
end
