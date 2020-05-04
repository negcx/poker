defmodule Poker.HandCategory.Straight do
  @enforce_keys [:rank, :cards]
  defstruct rank: nil, cards: nil

  @type t() :: %__MODULE__{
          rank: Poker.Rank.t(),
          cards: [Poker.Card.t()]
        }
end
