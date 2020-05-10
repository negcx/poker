defmodule Poker.Suit do
  @type t :: :clubs | :diamonds | :hearts | :spades

  @spec to_unicode(Poker.Suit.t()) :: String.t()
  def to_unicode(suit) do
    case suit do
      :clubs -> "♣"
      :diamonds -> "◆"
      :hearts -> "♥"
      :spades -> "♠"
    end
  end

  @spec from_unicode(String.t()) :: Poker.Suit.t()
  def from_unicode(u) do
    case u do
      "♣" -> :clubs
      "◆" -> :diamonds
      "♥" -> :hearts
      "♠" -> :spades
    end
  end

  @spec suits :: [Poker.Suit.t()]
  def suits() do
    [:spades, :hearts, :diamonds, :clubs]
  end
end
