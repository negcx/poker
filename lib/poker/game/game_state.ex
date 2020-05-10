defmodule Poker.Game.GameState do
  use TypedStruct

  typedstruct do
    field :config, Player.Game.Config.t(), enforce: true
    field :players, [Poker.Game.Player.t()]
    field :dealer, integer()
    field :action_to, integer()
    field :cards, [Poker.Card.t()]
    field :state, :waiting_for_players | :preflop, default: :waiting_for_players
  end
end
