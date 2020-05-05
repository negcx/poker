defmodule Poker.HandTest do
  use ExUnit.Case, async: true

  alias Poker.{Card, Hand}

  describe "Winners -" do
    test "Winners" do
      hand1 = %Hand{type: :three_kind, rank: :queen, kicker: [:ace, :king], cards: []}
      hand2 = %Hand{type: :four_kind, rank: :queen, kicker: :ace, cards: []}
      hand3 = %Hand{type: :four_kind, rank: :queen, kicker: :king, cards: []}

      assert Hand.winner([hand1, hand2, hand3]) == [hand2]
      assert Hand.winner([hand1, hand2, hand3, hand2]) == [hand2, hand2]
    end
  end

  describe "Like Hand Category Comparisons - " do
    test "Four of a Kind" do
      assert Hand.compare(
               %Hand{type: :four_kind, rank: :king, kicker: :five, cards: []},
               %Hand{type: :four_kind, rank: :queen, kicker: :ace, cards: []}
             ) == :gt

      assert Hand.compare(
               %Hand{type: :four_kind, rank: :seven, kicker: :five, cards: []},
               %Hand{type: :four_kind, rank: :seven, kicker: :ace, cards: []}
             ) == :lt

      assert Hand.compare(
               %Hand{type: :four_kind, rank: :ace, kicker: :five, cards: []},
               %Hand{type: :four_kind, rank: :ace, kicker: :five, cards: []}
             ) == :eq
    end

    test "Three of a Kind" do
      assert Hand.compare(
               %Hand{type: :three_kind, rank: :nine, kicker: [:ace, :queen], cards: []},
               %Hand{type: :three_kind, rank: :seven, kicker: [:ace, :queen], cards: []}
             ) == :gt

      assert Hand.compare(
               %Hand{type: :three_kind, rank: :seven, kicker: [:ace, :queen], cards: []},
               %Hand{type: :three_kind, rank: :nine, kicker: [:ace, :queen], cards: []}
             ) == :lt

      assert Hand.compare(
               %Hand{type: :three_kind, rank: :seven, kicker: [:ace, :queen], cards: []},
               %Hand{type: :three_kind, rank: :seven, kicker: [:ace, :queen], cards: []}
             ) == :eq
    end
  end

  describe "Unlike Hand Category Comparisons - " do
    test "Four of a Kind vs Three of a Kind" do
      assert Hand.compare(
               %Hand{type: :four_kind, rank: :two, kicker: :ace, cards: []},
               %Hand{type: :three_kind, rank: :ace, kicker: [:nine, :seven], cards: []}
             ) == :gt
    end
  end

  describe "Hand Values -" do
    test "Four of a Kind" do
      cards = [
        Card.new(:seven, :diamonds),
        Card.new(:seven, :clubs),
        Card.new(:seven, :spades),
        Card.new(:king, :hearts),
        Card.new(:two, :spades),
        Card.new(:ace, :spades),
        Card.new(:seven, :hearts)
      ]

      assert Hand.value(cards) == %Hand{
               type: :four_kind,
               rank: :seven,
               kicker: :ace,
               cards: [
                 Card.new(:seven, :diamonds),
                 Card.new(:seven, :clubs),
                 Card.new(:seven, :spades),
                 Card.new(:seven, :hearts),
                 Card.new(:ace, :spades)
               ]
             }
    end

    test "Four of a Kind (2x)" do
      cards = [
        Card.new(:seven, :diamonds),
        Card.new(:seven, :clubs),
        Card.new(:seven, :spades),
        Card.new(:six, :hearts),
        Card.new(:queen, :diamonds),
        Card.new(:two, :spades),
        Card.new(:three, :spades),
        Card.new(:seven, :hearts),
        Card.new(:queen, :clubs),
        Card.new(:queen, :spades),
        Card.new(:queen, :hearts)
      ]

      assert Hand.value(cards) == %Hand{
               type: :four_kind,
               rank: :queen,
               kicker: :seven,
               cards: [
                 Card.new(:queen, :diamonds),
                 Card.new(:queen, :clubs),
                 Card.new(:queen, :spades),
                 Card.new(:queen, :hearts),
                 Card.new(:seven, :diamonds)
               ]
             }
    end

    test "Flush" do
      cards = [
        Card.new(:seven, :diamonds),
        Card.new(:eight, :diamonds),
        Card.new(:king, :clubs),
        Card.new(:king, :diamonds),
        Card.new(:queen, :diamonds),
        Card.new(:two, :diamonds),
        Card.new(:six, :diamonds)
      ]

      assert Hand.value(cards) == %Hand{
               type: :flush,
               rank: [:king, :queen, :eight, :seven, :six],
               cards: [
                 Card.new(:king, :diamonds),
                 Card.new(:queen, :diamonds),
                 Card.new(:eight, :diamonds),
                 Card.new(:seven, :diamonds),
                 Card.new(:six, :diamonds)
               ]
             }
    end

    test "Three of a Kind" do
      cards = [
        Card.new(:seven, :diamonds),
        Card.new(:seven, :clubs),
        Card.new(:seven, :spades),
        Card.new(:king, :hearts),
        Card.new(:two, :spades),
        Card.new(:ace, :spades),
        Card.new(:nine, :hearts)
      ]

      assert Hand.value(cards) == %Hand{
               type: :three_kind,
               rank: :seven,
               kicker: [:ace, :king],
               cards: [
                 Card.new(:seven, :diamonds),
                 Card.new(:seven, :clubs),
                 Card.new(:seven, :spades),
                 Card.new(:ace, :spades),
                 Card.new(:king, :hearts)
               ]
             }
    end

    test "Two Pair" do
      cards = [
        Card.new(:seven, :diamonds),
        Card.new(:seven, :clubs),
        Card.new(:king, :spades),
        Card.new(:king, :hearts),
        Card.new(:two, :spades),
        Card.new(:ace, :spades),
        Card.new(:nine, :hearts)
      ]

      assert Hand.value(cards) == %Hand{
               type: :two_pair,
               rank: [:king, :seven],
               kicker: :ace,
               cards: [
                 Card.new(:king, :spades),
                 Card.new(:king, :hearts),
                 Card.new(:seven, :diamonds),
                 Card.new(:seven, :clubs),
                 Card.new(:ace, :spades)
               ]
             }
    end

    test "One Pair" do
      cards = [
        Card.new(:seven, :diamonds),
        Card.new(:eight, :clubs),
        Card.new(:king, :spades),
        Card.new(:king, :hearts),
        Card.new(:two, :spades),
        Card.new(:ace, :spades),
        Card.new(:nine, :hearts)
      ]

      assert Hand.value(cards) == %Hand{
               type: :one_pair,
               rank: :king,
               kicker: [:ace, :nine, :eight],
               cards: [
                 Card.new(:king, :spades),
                 Card.new(:king, :hearts),
                 Card.new(:ace, :spades),
                 Card.new(:nine, :hearts),
                 Card.new(:eight, :clubs)
               ]
             }
    end

    test "High Card" do
      cards = [
        Card.new(:seven, :diamonds),
        Card.new(:eight, :clubs),
        Card.new(:king, :spades),
        Card.new(:jack, :hearts),
        Card.new(:two, :spades),
        Card.new(:ace, :spades),
        Card.new(:nine, :hearts)
      ]

      assert Hand.value(cards) == %Hand{
               type: :high_card,
               rank: [:ace, :king, :jack, :nine, :eight],
               cards: [
                 Card.new(:ace, :spades),
                 Card.new(:king, :spades),
                 Card.new(:jack, :hearts),
                 Card.new(:nine, :hearts),
                 Card.new(:eight, :clubs)
               ]
             }
    end

    test "Full House" do
      cards = [
        Card.new(:eight, :diamonds),
        Card.new(:eight, :clubs),
        Card.new(:king, :spades),
        Card.new(:king, :hearts),
        Card.new(:two, :spades),
        Card.new(:king, :clubs),
        Card.new(:eight, :hearts)
      ]

      assert Hand.value(cards) == %Hand{
               type: :full_house,
               rank: [:king, :eight],
               cards: [
                 Card.new(:king, :spades),
                 Card.new(:king, :hearts),
                 Card.new(:king, :clubs),
                 Card.new(:eight, :diamonds),
                 Card.new(:eight, :clubs)
               ]
             }
    end

    test "Straight - Ace to Five" do
      cards = [
        Card.new(:ace, :diamonds),
        Card.new(:two, :clubs),
        Card.new(:three, :spades),
        Card.new(:four, :hearts),
        Card.new(:five, :spades),
        Card.new(:king, :clubs),
        Card.new(:eight, :hearts)
      ]

      assert Hand.value(cards) == %Hand{
               type: :straight,
               rank: :five,
               cards: [
                 Card.new(:five, :spades),
                 Card.new(:four, :hearts),
                 Card.new(:three, :spades),
                 Card.new(:two, :clubs),
                 Card.new(:ace, :diamonds)
               ]
             }
    end

    test "Straight - Ace to King" do
      cards = [
        Card.new(:ace, :diamonds),
        Card.new(:king, :clubs),
        Card.new(:queen, :spades),
        Card.new(:jack, :hearts),
        Card.new(:ten, :spades)
      ]

      assert Hand.value(cards) == %Hand{
               type: :straight,
               rank: :ace,
               cards: [
                 Card.new(:ace, :diamonds),
                 Card.new(:king, :clubs),
                 Card.new(:queen, :spades),
                 Card.new(:jack, :hearts),
                 Card.new(:ten, :spades)
               ]
             }
    end

    test "Straight Flush - Ace to Five" do
      cards = [
        Card.new(:ace, :diamonds),
        Card.new(:two, :diamonds),
        Card.new(:three, :diamonds),
        Card.new(:four, :diamonds),
        Card.new(:five, :diamonds),
        Card.new(:king, :clubs),
        Card.new(:eight, :diamonds)
      ]

      assert Hand.value(cards) == %Hand{
               type: :straight_flush,
               rank: :five,
               cards: [
                 Card.new(:five, :diamonds),
                 Card.new(:four, :diamonds),
                 Card.new(:three, :diamonds),
                 Card.new(:two, :diamonds),
                 Card.new(:ace, :diamonds)
               ]
             }
    end

    test "Straight Flush - Ace to King" do
      cards = [
        Card.new(:ace, :diamonds),
        Card.new(:king, :diamonds),
        Card.new(:queen, :diamonds),
        Card.new(:jack, :diamonds),
        Card.new(:ten, :diamonds)
      ]

      assert Hand.value(cards) == %Hand{
               type: :straight_flush,
               rank: :ace,
               cards: [
                 Card.new(:ace, :diamonds),
                 Card.new(:king, :diamonds),
                 Card.new(:queen, :diamonds),
                 Card.new(:jack, :diamonds),
                 Card.new(:ten, :diamonds)
               ]
             }
    end
  end
end
