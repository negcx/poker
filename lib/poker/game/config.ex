defmodule Poker.Game.Config do
  use TypedStruct

  typedstruct enforce: true do
    field :small_blind, float(), default: 1
    field :big_blind, float(), default: 2
    field :seats, integer(), default: 6
    field :buyin_min, float(), default: 100
    field :buyin_max, float(), default: 200
    field :turn_seconds, integer(), default: 30
  end
end
