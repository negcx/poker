defmodule Poker.GameHandTest do
  use ExUnit.Case, async: true

  alias Poker.Game.{GameHand, Config}
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
       "Kyle",
       "Gely",
       "Hugo"
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
      |> GameHand.call("Gely")

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

    hand = hand |> GameHand.call("Hugo")

    assert hand.round == :river

    folded_hand = hand

    hand =
      hand
      |> GameHand.bet("Gely", 20)
      |> GameHand.call("Hugo")

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
      |> GameHand.call("Gely")

    assert hand.round == :end
    assert Map.keys(hand.winners) -- ["Kyle", "Gely"] == []
  end

  test "Everyone's all in", state do
    hand =
      GameHand.new(state[:config], state[:stacked_deck], state[:players], state[:stacks])
      |> GameHand.all_in("Hugo")
      |> GameHand.all_in("Kyle")
      |> GameHand.call("Gely")

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
      "Kyle",
      "Gely",
      "Hugo",
      "Lily",
      "Tito"
    ]

    hand =
      GameHand.new(state[:config], stacked_deck, players, stacks)
      |> GameHand.raise("Hugo", 100)
      |> GameHand.call("Lily")
      |> GameHand.all_in("Tito")
      |> GameHand.all_in("Kyle")
      |> GameHand.all_in("Gely")
      |> GameHand.all_in("Hugo")
      |> GameHand.fold("Lily")

    assert hand.round == :end

    %{
      "Gely" => %{amount: 475.0, hand: _},
      "Hugo" => %{amount: 50.0, hand: _},
      "Kyle" => %{amount: 125.0, hand: _}
    } = hand.winners
  end

  test "Bet and raise size introspection", state do
    hand = GameHand.new(state[:config], state[:deck], state[:players], state[:stacks])

    assert GameHand.current_bet(hand) == 2
    assert GameHand.minimum_raise(hand) == 2

    hand = hand |> GameHand.raise("Hugo", 8)
    assert GameHand.minimum_raise(hand) == 6
  end

  test "Raise introspection - ignore all ins lower than allowed raise", state do
    hand = GameHand.new(state[:config], state[:deck], state[:players], state[:stacks])

    hand =
      hand
      |> GameHand.raise("Hugo", 80)
      |> GameHand.all_in("Kyle")

    assert GameHand.minimum_raise(hand) == 78
  end

  test "Call all in automatically", state do
    hand = GameHand.new(state[:config], state[:deck], state[:players], state[:stacks])

    hand =
      hand
      |> GameHand.all_in("Hugo")
      |> GameHand.call("Kyle")

    assert length(hand.actions |> Enum.filter(&(&1.player == "Kyle" && &1.action == :all_in))) ==
             1
  end

  test "Whose turn is it?", state do
    hand = GameHand.new(state[:config], state[:deck], state[:players], state[:stacks])

    assert GameHand.player_turn(hand) ==
             {"Hugo",
              [
                %{action: :fold, amount: 0},
                %{action: :all_in, amount: 100},
                %{action: :call, amount: 2},
                %{action: :raise, amount: 4, max: 100}
              ]}

    hand = hand |> GameHand.call("Hugo")

    assert GameHand.player_turn(hand) ==
             {"Kyle",
              [
                %{action: :fold, amount: 0},
                %{action: :all_in, amount: 99},
                %{action: :call, amount: 1},
                %{action: :raise, amount: 3, max: 99}
              ]}

    hand = hand |> GameHand.fold("Kyle")

    assert GameHand.player_turn(hand) ==
             {"Gely",
              [
                %{action: :fold, amount: 0},
                %{action: :all_in, amount: 148},
                %{action: :check, amount: 0},
                %{action: :raise, amount: 2, max: 148}
              ]}

    hand = hand |> GameHand.check("Gely")

    GameHand.current_bet(hand)
    GameHand.current_player_bet(hand, "Gely")
    GameHand.minimum_raise(hand)

    assert GameHand.player_turn(hand) ==
             {"Gely",
              [
                %{action: :fold, amount: 0},
                %{action: :all_in, amount: 148},
                %{action: :check, amount: 0},
                %{action: :bet, amount: 2, max: 148}
              ]}

    hand = hand |> GameHand.check("Gely")

    assert GameHand.player_turn(hand) ==
             {"Hugo",
              [
                %{action: :fold, amount: 0},
                %{action: :all_in, amount: 98},
                %{action: :check, amount: 0},
                %{action: :bet, amount: 2, max: 98}
              ]}
  end

  test "All in heads up ends early!", state do
    hand = GameHand.new(state[:config], state[:deck], ["Kyle", "Gely"], state[:stacks])

    hand = hand |> GameHand.call("Kyle")
    hand = hand |> GameHand.check("Gely")
    hand = hand |> GameHand.check("Kyle")
    hand = hand |> GameHand.check("Gely")

    hand = hand |> GameHand.all_in("Kyle")

    assert hand.round == :turn
  end
end
