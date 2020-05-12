defmodule Poker.GameHandTest do
  use ExUnit.Case, async: true

  alias Poker.Game.{Player, GameHand, Config}
  alias Poker.{Card, Deck}

  setup_all do
    stacked_deck =
      Deck.stack(
        [
          [%Poker.Card{rank: :ace, suit: :spades}, %Poker.Card{rank: :ace, suit: :hearts}],
          [%Poker.Card{rank: :ace, suit: :diamonds}, %Poker.Card{rank: :ace, suit: :clubs}],
          [
            %Poker.Card{rank: :two, suit: :diamonds},
            %Poker.Card{rank: :seven, suit: :diamonds}
          ]
        ],
        [
          %Poker.Card{rank: :eight, suit: :clubs},
          %Poker.Card{rank: :seven, suit: :clubs},
          %Poker.Card{rank: :king, suit: :hearts},
          %Poker.Card{rank: :queen, suit: :hearts},
          %Poker.Card{rank: :jack, suit: :spades}
        ]
      )

    {:ok,
     players: [
       %Player{name: "Kyle", player_id: 1},
       %Player{name: "Gely", player_id: 2},
       %Player{name: "Hugo", player_id: 3}
     ],
     deck: Deck.new(),
     config: %Config{},
     stacks: %{"Kyle" => 100, "Gely" => 150, "Hugo" => 100},
     stacked_deck: stacked_deck}
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

  test "A few simple hands with winners", state do
    hand =
      GameHand.new(state[:config], state[:deck], state[:players], state[:stacks])
      |> GameHand.raise("Hugo", 4)
      |> GameHand.fold("Kyle")
      |> GameHand.call("Gely", 2)

    assert hand.round == :flop
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

    folded_hand = hand
    folded_hand = folded_hand |> GameHand.fold("Hugo")

    assert folded_hand.round == :end

    hand = hand |> GameHand.call("Hugo", 8)

    assert hand.round == :river

    folded_hand = hand

    hand =
      hand
      |> GameHand.bet("Gely", 20)
      |> GameHand.call("Hugo", 20)

    assert hand.round == :end

    folded_hand =
      folded_hand
      |> GameHand.bet("Gely", 20)
      |> GameHand.fold("Hugo")

    assert folded_hand.round == :end
  end

  test "All in!", state do
    hand =
      GameHand.new(state[:config], state[:deck], state[:players], state[:stacks])
      |> GameHand.all_in("Hugo")
      |> GameHand.all_in("Kyle")
      |> GameHand.fold("Gely")

    assert Map.keys(hand.winners) |> hd == "Kyle"
  end

  test "All in, split pot", state do
    hand =
      GameHand.new(state[:config], state[:stacked_deck], state[:players], state[:stacks])
      |> GameHand.fold("Hugo")
      |> GameHand.all_in("Kyle")
      |> GameHand.call("Gely", 98)

    assert hand.round == :end
    assert Map.keys(hand.winners) -- ["Kyle", "Gely"] == []
  end

  test "Everyone's all in", state do
    hand =
      GameHand.new(state[:config], state[:stacked_deck], state[:players], state[:stacks])
      |> GameHand.all_in("Hugo")
      |> GameHand.all_in("Kyle")
      |> GameHand.call("Gely", 98)

    assert hand.round == :end
    assert Map.keys(hand.winners) -- ["Gely", "Kyle"] == []
  end

  test "Three all ins, side pots", state do
    stacks = %{"Kyle" => 50, "Gely" => 150, "Hugo" => 200, "Lily" => 125, "Tito" => 150}

    stacked_deck =
      Deck.stack(
        [
          [%Poker.Card{rank: :ace, suit: :spades}, %Poker.Card{rank: :ace, suit: :hearts}],
          [%Poker.Card{rank: :ace, suit: :diamonds}, %Poker.Card{rank: :ace, suit: :clubs}],
          [
            %Poker.Card{rank: :two, suit: :diamonds},
            %Poker.Card{rank: :seven, suit: :diamonds}
          ],
          [
            %Poker.Card{rank: :two, suit: :hearts},
            %Poker.Card{rank: :seven, suit: :hearts}
          ],
          [
            %Poker.Card{rank: :nine, suit: :hearts},
            %Poker.Card{rank: :four, suit: :hearts}
          ]
        ],
        [
          %Poker.Card{rank: :eight, suit: :clubs},
          %Poker.Card{rank: :seven, suit: :clubs},
          %Poker.Card{rank: :king, suit: :hearts},
          %Poker.Card{rank: :queen, suit: :hearts},
          %Poker.Card{rank: :jack, suit: :spades}
        ]
      )

    players = [
      %Player{name: "Kyle", player_id: 1},
      %Player{name: "Gely", player_id: 2},
      %Player{name: "Hugo", player_id: 3},
      %Player{name: "Lily", player_id: 4},
      %Player{name: "Tito", player_id: 5}
    ]

    hand =
      GameHand.new(state[:config], stacked_deck, players, stacks)
      |> GameHand.raise("Hugo", 100)
      |> GameHand.call("Lily", 100)
      |> GameHand.all_in("Tito")
      |> GameHand.all_in("Kyle")
      |> GameHand.all_in("Gely")
      |> GameHand.all_in("Hugo")
      |> GameHand.fold("Lily")

    assert hand.round == :end
    # Kyle and Gely both should split the pot that they have access to
    # Side Pot #1
    # - Kyle 100
    # - Gely 100
    # - Hugo 100
    # Kyle and Gely chop 300, 150 each
    # Side Pot #2
    # Gely 50
    # Hugo 50
    # Gely wins all 100
    # Side Pot #3
    # Hugo 50
    # Hugo wins 50
    # End result Kyle wins 150, Gely 250, Hugo 50

    %{"Kyle" => %{amount: 150}, "Gely" => %{amount: 450}, "Hugo" => %{amount: 50}} = hand.winners
  end
end
