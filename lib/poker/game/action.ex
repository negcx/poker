defmodule Poker.Game.Action do
  use TypedStruct

  @type action() :: :small_blind | :big_blind | :call | :bet | :raise | :fold | :check | :all_in

  typedstruct enforce: true do
    field :round, :preflop | :flop | :turn | :river
    field :action, __MODULE__.action()
    field :player, String.t()
    field :amount, float()
  end
end
