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

  @spec deal([Poker.Card.t()], integer()) :: {[Poker.Card.t()], [Poker.Card.t()]}
  def deal(deck, num) when length(deck) - num >= 0 do
    cards = Enum.take(deck, num)
    {deck -- cards, cards}
  end

  @spec stack([[Poker.Card.t()]], [Poker.Card.t()]) :: [Poker.Card.t()]
  def stack(player_cards, board) do
    deck =
      player_cards
      |> Enum.reduce(Poker.Deck.new() -- board, fn cards, deck ->
        deck -- cards
      end)

    {deck, burn_cards} = deal(deck, 3)

    player_cards
    |> List.flatten()
    |> Enum.take_every(2)
    |> Kernel.++(
      player_cards
      |> List.flatten()
      |> List.delete_at(0)
      |> Enum.take_every(2)
    )
    |> Kernel.++(burn_cards |> Enum.take(1))
    |> Kernel.++(board |> Enum.take(3))
    |> Kernel.++(burn_cards |> Enum.slice(1..1))
    |> Kernel.++(board |> Enum.slice(3..3))
    |> Kernel.++(burn_cards |> Enum.slice(2..2))
    |> Kernel.++(board |> Enum.slice(4..4))
    |> Kernel.++(deck)
  end
end
