defmodule Poker.HandCategory.ThreeKind do
  @enforce_keys [:rank, :kicker, :cards]
  defstruct rank: nil, kicker: nil, cards: nil

  @type t() :: %__MODULE__{
          rank: Poker.Rank.t(),
          kicker: [Poker.Rank.t()],
          cards: [Poker.Card.t()]
        }
end
