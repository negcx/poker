defmodule Poker.GameHandTest do
  use ExUnit.Case, async: true

  alias Poker.Game.{Player, GameHand, Config}
  alias Poker.{Card, Deck}

  setup_all do
    {:ok,
     players: [
       %Player{name: "Kyle", player_id: 1},
       %Player{name: "Gely", player_id: 2},
       %Player{name: "Hugo", player_id: 3}
     ],
     deck: Deck.new(),
     config: %Config{},
     stacks: %{"Kyle" => 100, "Gely" => 100, "Hugo" => 100}}
  end

  test "Deal the cards!", state do
    hand = GameHand.new(state[:config], state[:deck], state[:players], state[:stacks])

    assert hand.cards == %{
             "Kyle" => [%Card{suit: :spades, rank: :ace}, %Card{suit: :spades, rank: :jack}],
             "Gely" => [%Card{suit: :spades, rank: :king}, %Card{suit: :spades, rank: :ten}],
             "Hugo" => [%Card{suit: :spades, rank: :queen}, %Card{suit: :spades, rank: :nine}]
           }

    assert length(hand.deck) == 46
  end

  test "Raise and Call, Transition to Flop", state do
    hand =
      GameHand.new(state[:config], state[:deck], state[:players], state[:stacks])
      |> GameHand.raise("Hugo", 4)
      |> GameHand.fold("Kyle")
      |> GameHand.call("Gely", 2)

    assert GameHand.current_bet(hand) == 0

    assert GameHand.players_in_action(hand) == ["Gely", "Hugo"]

    assert hand.round == :flop

    hand =
      hand
      |> GameHand.check("Gely")
      |> GameHand.check("Hugo")

    assert hand.round == :turn

    hand =
      hand
      |> GameHand.check("Gely")
      |> GameHand.bet("Hugo", 8)
      |> GameHand.raise("Gely", 16)

    assert hand.round == :turn

    hand = hand |> GameHand.call("Hugo", 8)

    assert hand.round == :river

    hand =
      hand
      |> GameHand.bet("Gely", 20)
      |> GameHand.call("Hugo", 20)

    assert hand.round == :end
  end
end
