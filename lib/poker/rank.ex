defmodule Poker.Rank do
  @type t ::
          :two
          | :three
          | :four
          | :five
          | :six
          | :seven
          | :eight
          | :nine
          | :ten
          | :jack
          | :queen
          | :king
          | :ace

  @spec to_unicode(Poker.Rank.t()) :: String.t()
  def to_unicode(rank) do
    case rank do
      :two -> "2"
      :three -> "3"
      :four -> "4"
      :five -> "5"
      :six -> "6"
      :seven -> "7"
      :eight -> "8"
      :nine -> "9"
      :ten -> "10"
      :jack -> "J"
      :queen -> "Q"
      :king -> "K"
      :ace -> "A"
    end
  end

  # @spec from_unicode(String.t()) :: Poker.Rank.t()
  # def from_unicode(u) do
  #   case u do
  #     "2" -> :two
  #     "3" -> :three
  #     "4" -> :four
  #     "5" -> :five
  #     "6" -> :six
  #     "7" -> :seven
  #     "8" -> :eight
  #     "9" -> :nine
  #     "10" -> :ten
  #     "J" -> :jack
  #     "Q" -> :queen
  #     "K" -> :king
  #     "A" -> :ace
  #   end
  # end

  @spec to_integer(Poker.Rank.t()) :: integer()
  def to_integer(rank) do
    case rank do
      :two -> 2
      :three -> 3
      :four -> 4
      :five -> 5
      :six -> 6
      :seven -> 7
      :eight -> 8
      :nine -> 9
      :ten -> 10
      :jack -> 11
      :queen -> 12
      :king -> 13
      :ace -> 14
      nil -> 0
    end
  end

  # @spec from_integer(integer()) :: Poker.Rank.t()
  # def from_integer(i) do
  #   case i do
  #     1 -> :ace
  #     2 -> :two
  #     3 -> :three
  #     4 -> :four
  #     5 -> :five
  #     6 -> :six
  #     7 -> :seven
  #     8 -> :eight
  #     9 -> :nine
  #     10 -> :ten
  #     11 -> :jack
  #     12 -> :queen
  #     13 -> :king
  #     14 -> :ace
  #   end
  # end

  # @spec gt(Poker.Rank.t(), Poker.Rank.t()) :: boolean()
  # def gt(left, right) do
  #   Poker.Rank.to_integer(left) > Poker.Rank.to_integer(right)
  # end

  # @spec lt(Poker.Rank.t(), Poker.Rank.t()) :: boolean()
  # def lt(left, right) do
  #   Poker.Rank.to_integer(left) < Poker.Rank.to_integer(right)
  # end

  # @spec eq(Poker.Rank.t(), Poker.Rank.t()) :: boolean()
  # def eq(left, right) do
  #   Poker.Rank.to_integer(left) == Poker.Rank.to_integer(right)
  # end

  @spec ranks :: [Poker.Rank.t()]
  def ranks() do
    [
      :ace,
      :king,
      :queen,
      :jack,
      :ten,
      :nine,
      :eight,
      :seven,
      :six,
      :five,
      :four,
      :three,
      :two
    ]
  end

  @spec straight_ranks :: [Poker.Rank.t()]
  def straight_ranks() do
    ranks() ++ [:ace]
  end

  @spec compare([Poker.Rank.t()], [Poker.Rank.t()]) :: :gt | :eq | :lt
  def compare(left, right)
      when is_list(left) and is_list(right) and length(left) == length(right) do
    result =
      0..(length(left) - 1)
      |> Enum.to_list()
      |> Enum.map(fn n ->
        Poker.Rank.compare(Enum.fetch!(left, n), Enum.fetch!(right, n))
      end)
      |> Enum.filter(&(&1 != :eq))

    case result do
      [] -> :eq
      [r | _tail] -> r
    end
  end

  def compare(left, right) do
    case Poker.Rank.to_integer(left) - Poker.Rank.to_integer(right) do
      dif when dif > 0 ->
        :gt

      dif when dif == 0 ->
        :eq

      _ ->
        :lt
    end
  end
end
