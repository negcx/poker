defmodule Poker.Deck do
  @spec new :: [Poker.Card.t()]
  def new() do
    Poker.Suit.suits()
    |> Enum.flat_map(fn suit ->
      Poker.Rank.ranks()
      |> Enum.map(fn rank ->
        %Poker.Card{suit: suit, rank: rank}
      end)
    end)
  end

  @spec deal([Poker.Card.t()]) :: {[Poker.Card.t()], Poker.Card.t()}
  def deal(deck) when length(deck) > 0 do
    [card | deck] = deck
    {deck, card}
  end

  def deal(deck, num) when length(deck) - num >= 0 do
    cards = Enum.take(deck, num)
    {deck -- cards, cards}
  end
end
