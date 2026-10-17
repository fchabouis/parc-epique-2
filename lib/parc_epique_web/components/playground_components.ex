defmodule ParcEpiqueWeb.PlaygroundComponents do
  @moduledoc """
  The playground sheet: what the map shows when a playground is open, also
  rendered on its own page at `/:locale/aires/:id`.
  """
  use ParcEpiqueWeb, :html

  alias ParcEpique.Storage

  attr :playground, :map, required: true
  attr :ratings, :map, required: true
  attr :close, :string, required: true, doc: "where the close button leads"
  attr :review_form, :any, default: nil, doc: "the review form, when open"
  attr :register_prompt, :boolean, default: false, doc: "invite a guest to sign up"

  def playground_sheet(assigns) do
    assigns = assign(assigns, :detail, List.first(assigns.playground.details))

    ~H"""
    <article class="space-y-6 p-4">
      <header class="space-y-2">
        <div class="flex items-start justify-between gap-2">
          <h1 class="text-xl font-semibold">{playground_name(@playground)}</h1>
          <.link
            patch={@close}
            class="btn btn-ghost btn-sm btn-circle"
            aria-label={gettext("Close")}
          >
            <.icon name="hero-x-mark" class="size-5" />
          </.link>
        </div>
        <p class="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm">
          <span
            id={"distance-#{@playground.id}"}
            phx-hook="Distance"
            phx-update="ignore"
            data-lat={lat(@playground)}
            data-lng={lng(@playground)}
            data-template={gettext("%{distance} on foot", distance: "%{distance}")}
            hidden
          ></span>
          <a
            href={directions_url(@playground)}
            target="_blank"
            rel="noopener"
            class="link link-primary inline-flex items-center gap-1"
          >
            <.icon name="hero-map" class="size-4" /> {gettext("Directions")}
          </a>
        </p>
      </header>

      <section class="space-y-4">
        <div :if={@ratings.surroundings || @ratings.equipment} class="grid grid-cols-2 gap-4">
          <div>
            <h2 class="font-medium">{gettext("Surroundings")}</h2>
            <.stars value={@ratings.surroundings} class="size-6" />
          </div>
          <div>
            <h2 class="font-medium">{gettext("Equipment")}</h2>
            <.stars value={@ratings.equipment} class="size-6" />
          </div>
        </div>
        <p :if={!(@ratings.surroundings || @ratings.equipment)} class="italic">
          {gettext("No rating yet, be the first to write a review!")}
        </p>

        <ul :if={@playground.reviews != []} id="reviews" class="space-y-4">
          <li :for={review <- @playground.reviews} id={"review-#{review.id}"}>
            <p class="text-sm text-base-content/70">
              {gettext("%{name}, on %{date}",
                name: review.display_name || gettext("Anonymous"),
                date: format_date(review.inserted_at)
              )}
            </p>
            <p class="flex flex-wrap items-center gap-x-2 text-sm">
              {gettext("Surroundings")} <.stars value={review.rating_surroundings} />
              {gettext("Equipment")} <.stars value={review.rating_equipment} />
            </p>
            <p :if={review.comment} class="mt-1">“{review.comment}”</p>
          </li>
        </ul>

        <div :if={@register_prompt} id="register-prompt" role="status" class="alert alert-info">
          <span>{gettext("How about registering so that your contributions bear your name?")}</span>
          <.link href={~p"/users/register"} class="btn btn-sm">{gettext("Sign up")}</.link>
        </div>

        <.form
          :if={@review_form}
          for={@review_form}
          id="review-form"
          phx-change="validate_review"
          phx-submit="save_review"
          class="space-y-2"
        >
          <.rating_input field={@review_form[:rating_surroundings]} label={gettext("Surroundings")} />
          <.rating_input field={@review_form[:rating_equipment]} label={gettext("Equipment")} />
          <.input
            field={@review_form[:comment]}
            type="textarea"
            label={gettext("Comment (optional)")}
          />
          <div class="flex gap-2">
            <.button variant="primary" phx-disable-with={gettext("Publishing...")}>
              {gettext("Publish")}
            </.button>
            <button type="button" class="btn btn-ghost" phx-click="cancel_review">
              {gettext("Cancel")}
            </button>
          </div>
        </.form>

        <button
          :if={!@review_form}
          type="button"
          id="write-review"
          class="btn btn-primary btn-soft btn-sm"
          phx-click="new_review"
        >
          {gettext("Write a review")}
        </button>
      </section>

      <section class="space-y-2 border-t border-base-300 pt-4">
        <h2 class="font-medium">{gettext("Details")}</h2>
        <p :if={!described?(@detail)} class="italic">
          {gettext("This playground has no description yet. Your turn!")}
        </p>
        <div :if={described?(@detail)} class="space-y-2">
          <p :if={!is_nil(@detail.free)}>
            {if @detail.free, do: gettext("Free"), else: gettext("Paid")}
          </p>
          <p :if={!is_nil(@detail.open_at_night)}>
            {if @detail.open_at_night, do: gettext("Open at night"), else: gettext("Closed at night")}
          </p>
          <p :if={!is_nil(@detail.private)}>
            {if @detail.private, do: gettext("Private"), else: gettext("Public")}
          </p>
          <ul :if={@detail.equipment != []} class="flex flex-wrap gap-2">
            <li :for={code <- @detail.equipment} class="badge badge-primary badge-soft">
              {equipment_label(code)}
            </li>
          </ul>
        </div>
        <.coming_soon label={gettext("Suggest a change")} />
      </section>

      <section class="space-y-2 border-t border-base-300 pt-4">
        <h2 class="font-medium">{gettext("Photos")}</h2>
        <ul :if={@playground.photos != []} class="grid grid-cols-3 gap-2">
          <li :for={photo <- @playground.photos} id={"photo-#{photo.id}"}>
            <button
              type="button"
              phx-click="show_photo"
              phx-value-id={photo.id}
              class="block w-full cursor-zoom-in"
              aria-label={gettext("Enlarge the photo")}
            >
              <img
                src={Storage.url(photo.thumbnail_path || photo.path)}
                alt=""
                loading="lazy"
                class="aspect-square w-full rounded object-cover"
              />
            </button>
          </li>
        </ul>
        <.coming_soon label={gettext("Add a photo")} />
      </section>

      <section class="border-t border-base-300 pt-4">
        <.coming_soon label={gettext("Report that this playground no longer exists")} />
      </section>
    </article>
    """
  end

  @rating_values Enum.map(1..10, &(&1 / 2))

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true

  defp rating_input(assigns) do
    assigns =
      assign(assigns,
        ratings: @rating_values,
        selected: to_rating(assigns.field.value),
        errors:
          if(Phoenix.Component.used_input?(assigns.field), do: assigns.field.errors, else: [])
      )

    ~H"""
    <fieldset class="fieldset">
      <legend class="fieldset-legend">{@label}</legend>
      <div class="rating rating-lg rating-half">
        <input
          :for={rating <- @ratings}
          type="radio"
          id={"#{@field.id}_#{trunc(rating * 2)}"}
          name={@field.name}
          value={rating}
          checked={rating == @selected}
          aria-label={rating_label(rating)}
          class={[
            "mask mask-star-2 bg-warning",
            if(rating == trunc(rating), do: "mask-half-2", else: "mask-half-1")
          ]}
        />
      </div>
      <p :for={msg <- Enum.map(@errors, &translate_error/1)} class="text-sm text-error">{msg}</p>
    </fieldset>
    """
  end

  defp to_rating(value) when is_number(value), do: value * 1.0

  defp to_rating(value) when is_binary(value) do
    case Float.parse(value) do
      {rating, _} -> rating
      :error -> nil
    end
  end

  defp to_rating(_value), do: nil

  # The other contribution forms come with issues #10 to #12.
  attr :label, :string, required: true

  defp coming_soon(assigns) do
    ~H"""
    <button type="button" class="btn btn-ghost btn-sm" disabled title={gettext("Coming soon")}>
      {@label}
    </button>
    """
  end

  attr :photo, :map, required: true

  def photo_modal(assigns) do
    ~H"""
    <div
      id="photo-modal"
      class="modal modal-open z-[2000]"
      phx-window-keydown="hide_photo"
      phx-key="Escape"
    >
      <div class="modal-box max-w-4xl p-2">
        <img src={Storage.url(@photo.path)} alt="" class="w-full rounded" />
      </div>
      <button type="button" class="modal-backdrop" phx-click="hide_photo">
        {gettext("Close")}
      </button>
    </div>
    """
  end

  @doc """
  Renders a 0 to 5 rating as five stars, filled in proportion. A missing
  rating shows empty stars.
  """
  attr :value, :float, default: nil
  attr :class, :string, default: "size-4"

  def stars(assigns) do
    assigns = assign(assigns, :percent, round((assigns.value || 0) / 5 * 100))

    ~H"""
    <span
      class="relative inline-flex align-middle"
      role="img"
      aria-label={rating_label(@value)}
    >
      <span class="flex text-base-300">
        <.icon :for={_ <- 1..5} name="hero-star-solid" class={[@class, "shrink-0"]} />
      </span>
      <span
        class="absolute inset-y-0 left-0 flex overflow-hidden text-warning"
        style={"width: #{@percent}%"}
      >
        <.icon :for={_ <- 1..5} name="hero-star-solid" class={[@class, "shrink-0"]} />
      </span>
    </span>
    """
  end

  defp rating_label(nil), do: gettext("Not rated")

  defp rating_label(value) do
    rating =
      value
      |> Kernel.*(1.0)
      |> :erlang.float_to_binary(decimals: 1)
      |> String.replace(".", pgettext("decimal separator", "."))

    gettext("%{rating} out of 5", rating: rating)
  end

  def playground_name(%{name: name}) when is_binary(name) and name != "", do: name
  def playground_name(_playground), do: gettext("Playground")

  def lat(%{location: %Geo.Point{coordinates: {_lng, lat}}}), do: lat
  def lng(%{location: %Geo.Point{coordinates: {lng, _lat}}}), do: lng

  @doc "A Google Maps walking itinerary to the playground, from where the visitor is."
  def directions_url(playground) do
    "https://www.google.com/maps/dir/?" <>
      URI.encode_query(%{
        "api" => "1",
        "destination" => "#{lat(playground)},#{lng(playground)}",
        "travelmode" => "walking"
      })
  end

  defp described?(nil), do: false

  defp described?(detail) do
    detail.equipment != [] or
      Enum.any?([detail.free, detail.open_at_night, detail.private], &(not is_nil(&1)))
  end

  def format_date(%DateTime{} = datetime), do: format_date(DateTime.to_date(datetime))

  def format_date(%Date{} = date) do
    gettext("%{month} %{day}, %{year}",
      day: date.day,
      month: month_name(date.month),
      year: date.year
    )
  end

  defp month_name(1), do: gettext("January")
  defp month_name(2), do: gettext("February")
  defp month_name(3), do: gettext("March")
  defp month_name(4), do: gettext("April")
  defp month_name(5), do: gettext("May")
  defp month_name(6), do: gettext("June")
  defp month_name(7), do: gettext("July")
  defp month_name(8), do: gettext("August")
  defp month_name(9), do: gettext("September")
  defp month_name(10), do: gettext("October")
  defp month_name(11), do: gettext("November")
  defp month_name(12), do: gettext("December")

  @doc "The visitor-facing name of an equipment code (see `ParcEpique.Playgrounds.Equipment`)."
  def equipment_label("slide"), do: gettext("Slide")
  def equipment_label("springy"), do: gettext("Spring rider")
  def equipment_label("climbingframe"), do: gettext("Climbing frame")
  def equipment_label("rope_traverse"), do: gettext("Rope bridge")
  def equipment_label("drinking_water"), do: gettext("Drinking fountain")
  def equipment_label("toilets"), do: gettext("Toilets")
  def equipment_label("sandpit"), do: gettext("Sandpit")
  def equipment_label("table_tennis"), do: gettext("Table tennis")
  def equipment_label("soccer"), do: gettext("Football pitch")
  def equipment_label("basketball"), do: gettext("Basketball court")
  def equipment_label("boules"), do: gettext("Pétanque court")
  def equipment_label("playhouse"), do: gettext("Playhouse")
  def equipment_label("car_track"), do: gettext("Car track")
  def equipment_label("roundabout"), do: gettext("Roundabout")
  def equipment_label(code), do: code
end
