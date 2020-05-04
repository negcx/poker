defmodule Poker.RankTest do
  use ExUnit.Case, async: true

  alias Poker.{Rank}

  describe "Rank Comparisons - " do
    test "Rank Comparisons" do
      assert Rank.compare(:ace, :king) == :gt
      assert Rank.compare(:king, :king) == :eq
      assert Rank.compare(:two, :three) == :lt
    end

    test "Rank List Comparisons" do
      assert Rank.compare([:ace, :king, :ten], [:ace, :king, :jack]) == :lt
      assert Rank.compare([:ace, :king, :ten], [:ace, :king, :ten]) == :eq
      assert Rank.compare([:ace, :king, :ten], [:ace, :king, :two]) == :gt
    end
  end
end
