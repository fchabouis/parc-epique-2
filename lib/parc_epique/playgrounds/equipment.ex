defmodule ParcEpique.Playgrounds.Equipment do
  @moduledoc """
  Equipment codes for a playground.

  Codes follow OpenStreetMap `playground=*` values where one exists, so they
  can later be filled in from OSM. `from_legacy_label/1` converts the French
  labels stored in Firebase.
  """

  @codes ~w(slide springy climbingframe rope_traverse drinking_water toilets sandpit
            table_tennis soccer basketball boules playhouse car_track roundabout)

  @legacy_labels %{
    "toboggan" => "slide",
    "cheval à bascule" => "springy",
    "escalade" => "climbingframe",
    "pont de singe" => "rope_traverse",
    "fontaine" => "drinking_water",
    "toilettes" => "toilets",
    "bac à sable" => "sandpit",
    "table de ping-pong" => "table_tennis",
    "terrain de foot" => "soccer",
    "terrain de basket" => "basketball",
    "terrain de pétanque" => "boules",
    "cabane" => "playhouse",
    "circuit de voitures" => "car_track",
    "tourniquet" => "roundabout"
  }

  def codes, do: @codes

  @doc """
  Returns `{:ok, code}` for a known Firebase label, `:error` otherwise.
  """
  def from_legacy_label(label) when is_binary(label) do
    Map.fetch(@legacy_labels, label |> String.trim() |> String.downcase())
  end
end
