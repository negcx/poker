defmodule Poker.Card do
  @enforce_keys [:suit, :rank]
  defstruct suit: nil, rank: nil

  @type t() :: %__MODULE__{
          suit: Poker.Suit.t(),
          rank: Poker.Rank.t()
        }

  defimpl String.Chars, for: Poker.Card do
    @spec to_string(Poker.Card.t()) :: String.t()
    def to_string(card) do
      Poker.Rank.to_unicode(card.rank) <> Poker.Suit.to_unicode(card.suit)
    end
  end

  @spec new(Poker.Rank.t(), Poker.Suit.t()) :: Poker.Card.t()
  def new(rank, suit) do
    %Poker.Card{
      suit: suit,
      rank: rank
    }
  end
end
