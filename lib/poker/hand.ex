defmodule Poker.Hand do
  @enforce_keys [:type, :rank, :cards]
  defstruct type: nil, rank: nil, kicker: nil, cards: nil

  @type t() :: %__MODULE__{
          type:
            :straight_flush
            | :four_kind
            | :full_house
            | :flush
            | :straight
            | :three_kind
            | :two_pair
            | :one_pair
            | :high_card,
          rank: Poker.Rank.t() | [Poker.Rank.t()],
          kicker: nil | Poker.Rank.t() | [Poker.Rank.t()],
          cards: [Poker.Card.t()]
        }

  @types [
    :high_card,
    :one_pair,
    :two_pair,
    :three_kind,
    :straight,
    :flush,
    :full_house,
    :four_kind,
    :straight_flush
  ]

  def value(cards)
      when length(cards) >= 5 and
             is_list(cards) do
    {:done, value} =
      {:continue, cards}
      |> straight_flush?
      |> four_of_a_kind?
      |> full_house?
      |> flush?
      |> straight?
      |> three_of_a_kind?
      |> two_pair?
      |> one_pair?
      |> high_card?

    value
  end

  defp straight_flush?({_, cards}) do
    case cards
         |> Enum.group_by(& &1.suit, & &1)
         |> Enum.filter(fn {_suit, cards} -> length(cards) >= 5 end) do
      [] ->
        {:continue, cards}

      [{_suit, cards} | _tail] ->
        case straight?({:continue, cards}) do
          {:done, hand} ->
            {
              :done,
              %Poker.Hand{
                type: :straight_flush,
                rank: hand.rank,
                cards: hand.cards
              }
            }

          {:continue, cards} ->
            {:continue, cards}
        end
    end
  end

  defp four_of_a_kind?({:done, hand}), do: {:done, hand}

  defp four_of_a_kind?({:continue, cards}) do
    case cards
         |> Enum.group_by(& &1.rank, & &1)
         |> Enum.filter(fn {_rank, cards} -> length(cards) == 4 end)
         |> Enum.sort_by(fn {rank, _} -> Poker.Rank.to_integer(rank) end, :desc) do
      [] ->
        {:continue, cards}

      [{rank, four_cards} | _tail] ->
        kicker =
          (cards -- four_cards)
          |> Enum.sort_by(&Poker.Rank.to_integer(&1.rank), :desc)
          |> hd

        {:done,
         %Poker.Hand{
           type: :four_kind,
           rank: rank,
           kicker: kicker.rank,
           cards: four_cards ++ [kicker]
         }}
    end
  end

  defp full_house?({:done, hand}), do: {:done, hand}

  defp full_house?({:continue, cards}) do
    case cards
         |> Enum.group_by(& &1.rank, & &1)
         |> Enum.filter(fn {_rank, cards} -> length(cards) >= 2 end)
         |> Enum.sort_by(
           fn {rank, cards} -> {length(cards), Poker.Rank.to_integer(rank)} end,
           :desc
         )
         |> Enum.take(2) do
      [] ->
        {:continue, cards}

      [{rank, three_cards} | [{pair_rank, pair_cards}]] when length(three_cards) == 3 ->
        {:done,
         %Poker.Hand{
           type: :full_house,
           rank: [rank, pair_rank],
           cards: three_cards ++ (pair_cards |> Enum.take(2))
         }}

      _ ->
        {:continue, cards}
    end
  end

  defp flush?({:continue, cards}) do
    case cards
         |> Enum.group_by(& &1.suit, & &1)
         |> Enum.filter(fn {_suit, cards} -> length(cards) >= 5 end) do
      [] ->
        {:continue, cards}

      [{_suit, cards} | _tail] ->
        cards =
          cards
          |> Enum.sort_by(&Poker.Rank.to_integer(&1.rank), :desc)
          |> Enum.take(5)

        ranks =
          cards
          |> Enum.map(& &1.rank)

        {:done,
         %Poker.Hand{
           type: :flush,
           rank: ranks,
           cards: cards
         }}
    end
  end

  defp flush?({:done, hand}), do: {:done, hand}

  defp straight?({:done, hand}), do: {:done, hand}

  defp straight?({:continue, cards}) do
    straight_ranks = Poker.Rank.straight_ranks()

    card_ranks =
      0..(length(straight_ranks) - 5)
      |> Enum.to_list()
      |> Enum.map(fn i ->
        slice = Enum.slice(straight_ranks, i, 5)
        card_ranks = cards |> Enum.map(& &1.rank)

        if length(card_ranks) - 5 == length(card_ranks -- slice) do
          slice
        else
          nil
        end
      end)
      |> Enum.filter(&(&1 != nil))

    if length(card_ranks) > 0 do
      highest_card_ranks = card_ranks |> hd
      rank = highest_card_ranks |> hd

      straight_cards =
        highest_card_ranks
        |> Enum.map(fn rank ->
          Enum.find(cards, &(&1.rank == rank))
        end)

      {:done,
       %Poker.Hand{
         type: :straight,
         rank: rank,
         cards: straight_cards
       }}
    else
      {:continue, cards}
    end
  end

  defp three_of_a_kind?({:done, hand}), do: {:done, hand}

  defp three_of_a_kind?({:continue, cards}) do
    case cards
         |> Enum.group_by(& &1.rank, & &1)
         |> Enum.filter(fn {_rank, cards} -> length(cards) == 3 end)
         |> Enum.sort_by(fn {rank, _} -> Poker.Rank.to_integer(rank) end, :desc) do
      [] ->
        {:continue, cards}

      [{rank, three_cards} | _tail] ->
        kicker =
          (cards -- three_cards)
          |> Enum.sort_by(&Poker.Rank.to_integer(&1.rank), :desc)
          |> Enum.take(2)

        {:done,
         %Poker.Hand{
           type: :three_kind,
           rank: rank,
           kicker: Enum.map(kicker, & &1.rank),
           cards: three_cards ++ kicker
         }}
    end
  end

  defp two_pair?({:done, hand}), do: {:done, hand}

  defp two_pair?({:continue, cards}) do
    case cards
         |> Enum.group_by(& &1.rank, & &1)
         |> Enum.filter(fn {_rank, cards} -> length(cards) == 2 end)
         |> Enum.sort_by(fn {rank, _} -> Poker.Rank.to_integer(rank) end, :desc)
         |> Enum.take(2) do
      [] ->
        {:continue, cards}

      pairs when length(pairs) >= 2 ->
        rank = pairs |> Enum.map(fn {rank, _} -> rank end)

        pair_cards = pairs |> Enum.flat_map(fn {_rank, cards} -> cards end)

        kicker =
          (cards -- pair_cards)
          |> Enum.sort_by(&Poker.Rank.to_integer(&1.rank), :desc)
          |> hd

        {:done,
         %Poker.Hand{
           type: :two_pair,
           rank: rank,
           kicker: kicker.rank,
           cards: pair_cards ++ [kicker]
         }}

      _ ->
        {:continue, cards}
    end
  end

  defp one_pair?({:done, hand}), do: {:done, hand}

  defp one_pair?({:continue, cards}) do
    case cards
         |> Enum.group_by(& &1.rank, & &1)
         |> Enum.filter(fn {_rank, cards} -> length(cards) == 2 end)
         |> Enum.sort_by(fn {rank, _} -> Poker.Rank.to_integer(rank) end, :desc) do
      [] ->
        {:continue, cards}

      [{rank, pair_cards} | _tail] ->
        kicker =
          (cards -- pair_cards)
          |> Enum.sort_by(&Poker.Rank.to_integer(&1.rank), :desc)
          |> Enum.take(3)

        {:done,
         %Poker.Hand{
           type: :one_pair,
           rank: rank,
           kicker: Enum.map(kicker, & &1.rank),
           cards: pair_cards ++ kicker
         }}
    end
  end

  defp high_card?({:done, hand}), do: {:done, hand}

  defp high_card?({:continue, cards}) do
    cards =
      cards
      |> Enum.sort_by(&Poker.Rank.to_integer(&1.rank), :desc)
      |> Enum.take(5)

    {:done,
     %Poker.Hand{
       type: :high_card,
       rank: cards |> Enum.map(& &1.rank),
       cards: cards
     }}
  end

  defp type_to_integer(type) do
    case type do
      :high_card -> 0
      :one_pair -> 1
      :two_pair -> 2
      :three_kind -> 3
      :straight -> 4
      :flush -> 5
      :full_house -> 6
      :four_kind -> 7
      :straight_flush -> 8
    end
  end

  def compare(left_type, right_type)
      when left_type in @types and right_type in @types do
    case type_to_integer(left_type) - type_to_integer(right_type) do
      dif when dif > 0 -> :gt
      dif when dif == 0 -> :eq
      _ -> :lt
    end
  end

  def compare(%{type: left_type}, %{type: right_type})
      when left_type != right_type do
    compare(left_type, right_type)
  end

  def compare(%{type: left_type, rank: left_rank, kicker: left_kicker}, %{
        type: right_type,
        rank: right_rank,
        kicker: right_kicker
      })
      when left_type == right_type do
    case Poker.Rank.compare(left_rank, right_rank) do
      :lt -> :lt
      :gt -> :gt
      :eq -> Poker.Rank.compare(left_kicker, right_kicker)
    end
  end

  def compare(%{type: left_type, rank: left_rank}, %{
        type: right_type,
        rank: right_rank
      })
      when left_type == right_type do
    Poker.Rank.compare(left_rank, right_rank)
  end

  def gt(left, right) do
    case compare(left, right) do
      :gt -> true
      _ -> false
    end
  end

  def lt(left, right) do
    case compare(left, right) do
      :lt -> true
      _ -> false
    end
  end

  def gte(left, right) do
    case compare(left, right) do
      :gt -> true
      :eq -> true
      _ -> false
    end
  end

  def eq(left, right) do
    case compare(left, right) do
      :eq -> true
      _ -> false
    end
  end

  def lte(left, right) do
    case compare(left, right) do
      :lt -> true
      :eq -> true
      _ -> false
    end
  end

  def winner(hands) when is_list(hands) do
    sorted_hands =
      hands
      |> Enum.sort_by(& &1, &Poker.Hand.gte/2)

    sorted_hands
    |> Enum.filter(&Poker.Hand.eq(sorted_hands |> hd, &1))
  end
end
