defmodule Poker.Game.Player do
  use TypedStruct

  typedstruct enforce: true do
    field :player_id, integer()
    field :name, String.t()
  end
end
