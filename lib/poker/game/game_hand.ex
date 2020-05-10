defmodule Poker.Game.GameHand do
  use TypedStruct

  require Logger
  alias Poker.Game.Action

  @type(game_round() :: :new | :preflop | :flop | :turn | :river | :end, default: :new)

  typedstruct enforce: true do
    field :deck, Poker.Deck.t()
    field :round, __MODULE__.game_round(), default: :new
    field :players, [String.t()]
    field :stacks, %{String.t() => float()}
    field :board, [Poker.Card.t()], default: []
    field :cards, %{String.t() => [Poker.Card.t()]}, enforce: false, default: nil
    field :burn, [Poker.Card.t()], default: []
    field :actions, [Poker.Game.Action.t()], default: []
    field :config, Poker.Game.Config.t()
    field :winners, [%{String.t() => %{amount: float(), hand: Poker.Hand.t()}}], default: []
  end

  @spec new(Poker.Game.Config.t(), [Poker.Deck.t()], [Poker.Game.Player.t()], %{
          String.t() => float()
        }) :: __MODULE__.t()
  def new(config, deck, players, stacks) do
    %__MODULE__{
      deck: deck,
      players: players |> Enum.map(& &1.name),
      stacks: stacks,
      config: config
    }
    |> transition()
  end

  @spec deal(Poker.Game.GameHand.t()) :: Poker.Game.GameHand.t()
  defp deal(%__MODULE__{round: :new, cards: nil, players: players, deck: deck} = hand) do
    {cards, deck} =
      (players ++ players)
      |> Enum.reduce({[], deck}, fn player, {output, deck} ->
        {deck, card} = Poker.Deck.deal(deck)
        {output ++ [{player, card}], deck}
      end)

    cards =
      cards
      |> Enum.group_by(fn {key, _value} -> key end, fn {_key, value} -> value end)

    hand = put_in(hand.deck, deck)
    hand = put_in(hand.cards, cards)

    hand
  end

  defp action(hand, action) do
    action |> debug_action

    %{hand | actions: hand.actions ++ [action]}
    |> update_stack(action.player, -action.amount)
    |> transition()
  end

  defp update_stack(hand, player, change) do
    %{hand | stacks: Map.update!(hand.stacks, player, &(&1 + change))}
  end

  @spec small_blind(Poker.Game.GameHand.t()) :: Poker.Game.GameHand.t()
  def small_blind(%__MODULE__{round: :preflop, actions: []} = hand) do
    player = hand.players |> hd
    amount = min(hand.config.small_blind, Map.get(hand.stacks, player))

    hand
    |> action(%Action{round: :preflop, action: :small_blind, player: player, amount: amount})
  end

  @spec big_blind(Poker.Game.GameHand.t()) :: Poker.Game.GameHand.t()
  def big_blind(%__MODULE__{round: :preflop, actions: actions} = hand)
      when length(actions) == 1 do
    player = hand.players |> Enum.fetch!(1)
    amount = min(hand.config.big_blind, Map.get(hand.stacks, player))

    hand
    |> action(%Action{round: :preflop, action: :big_blind, player: player, amount: amount})
  end

  @spec call(%{actions: [any], round: any}, any, any) :: %{actions: [...], round: any}
  def call(hand, player, amount) do
    hand
    |> action(%Action{
      player: player,
      amount: amount,
      round: hand.round,
      action: :call
    })
  end

  def raise(hand, player, amount) do
    hand
    |> action(%Action{
      player: player,
      amount: amount,
      round: hand.round,
      action: :raise
    })
  end

  def bet(hand, player, amount) do
    hand
    |> action(%Action{
      player: player,
      amount: amount,
      round: hand.round,
      action: :bet
    })
  end

  def fold(hand, player) do
    hand
    |> action(%Action{
      player: player,
      amount: 0,
      round: hand.round,
      action: :fold
    })
  end

  def check(hand, player) do
    hand
    |> action(%Action{
      player: player,
      amount: 0,
      round: hand.round,
      action: :check
    })
  end

  def current_bet(hand) do
    bets =
      hand.actions
      |> Enum.filter(&(&1.round == hand.round))
      |> Enum.group_by(& &1.player, & &1.amount)
      |> Enum.reduce(Map.new(), fn {player, bets}, map ->
        total_bets =
          bets
          |> Enum.reduce(0, fn bet, total ->
            total + bet
          end)

        map |> Map.put(player, total_bets)
      end)
      |> Enum.sort_by(fn {_player, bet} -> bet end, :desc)

    case bets do
      [] ->
        0

      [{_player, bet} | _bets] ->
        bet
    end
  end

  def player_bets(hand, round) do
    hand.actions
    |> Enum.filter(&(&1.round == round))
    |> Enum.group_by(& &1.player, &%{action: &1.action, bet: &1.amount})
    |> Enum.reduce(Map.new(), fn {player, actions}, map ->
      total_bets =
        actions
        |> Enum.reduce(0, fn action, total ->
          total + action.bet
        end)

      map
      |> Map.put(player, %{
        bet: total_bets,
        action: List.last(actions).action
      })
    end)
  end

  def player_bets(hand) do
    player_bets(hand, hand.round)
  end

  def terminating_action(hand, round) do
    hand.actions
    |> Enum.filter(&(&1.round == round))
    |> Enum.filter(&(&1.action in [:all_in, :fold]))
    |> Enum.map(& &1.player)
  end

  def players_in_action(hand, round) do
    case round do
      :new ->
        hand.players

      :preflop ->
        hand.players -- terminating_action(hand, :preflop)

      :flop ->
        players_in_action(hand, :preflop) -- terminating_action(hand, :flop)

      :turn ->
        players_in_action(hand, :flop) -- terminating_action(hand, :turn)

      :river ->
        players_in_action(hand, :turn) -- terminating_action(hand, :river)

      :end ->
        []
    end
  end

  def players_in_action(hand) do
    players_in_action(hand, hand.round)
  end

  def players_who_acted(hand, round) do
    hand.actions
    |> Enum.filter(&(&1.round == round))
    |> Enum.filter(&(&1.action not in [:small_blind, :big_blind]))
    |> Enum.map(& &1.player)
    |> MapSet.new()
    |> MapSet.to_list()
  end

  defp prev_round(round) do
    case round do
      :preflop -> :new
      :flop -> :preflop
      :turn -> :flop
      :river -> :turn
    end
  end

  defp should_transition?(hand) do
    # In order to transition from preflop to flop, the following
    # conditions must be true:
    # 1. All players have acted
    # 2. All players in a non-terminating state have the same
    # bet amount.

    case players_in_action(hand, prev_round(hand.round)) -- players_who_acted(hand, hand.round) do
      [] ->
        number_of_bets =
          hand
          |> player_bets()
          |> Enum.filter(fn {_player, action} ->
            action.action not in [:all_in, :fold]
          end)
          |> Enum.group_by(fn {_player, action} -> action.bet end)
          |> Map.keys()
          |> length

        case number_of_bets do
          1 -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  def debug_game_state(hand) do
    Logger.debug("Round #{hand.round}")

    board =
      hand.board
      |> Enum.map(&to_string/1)
      |> Enum.join(" ")

    Logger.debug("Board #{board}")

    Logger.debug("Players")

    _ =
      hand
      |> players_in_action
      |> Enum.map(fn player ->
        stack = Map.get(hand.stacks, player)
        cards = Map.get(hand.cards, player, [])
        cards = cards |> Enum.map(&to_string/1) |> Enum.join(" ")

        Logger.debug("   #{player} #{stack} #{cards}")
      end)

    _ =
      case hand.winners do
        [] ->
          nil

        winners ->
          winners
          |> Enum.map(fn {player, map} ->
            Logger.debug("   #{player} won #{map.amount} with #{map.hand.type}")
          end)
      end

    Logger.debug("")

    hand
  end

  def debug_action(action) do
    Logger.debug("   Action #{action.player} #{action.action} #{action.amount}")
  end

  def transition(%{round: :new} = hand) do
    hand
    |> deal()
    |> Map.put(:round, :preflop)
    |> small_blind
    |> big_blind
    |> debug_game_state()
  end

  def transition(%{round: :preflop} = hand) do
    case should_transition?(hand) do
      true ->
        {deck, burn_card} = Poker.Deck.deal(hand.deck)
        {deck, flop} = Poker.Deck.deal(deck, 3)

        %{hand | round: :flop, board: flop, burn: [burn_card], deck: deck}
        |> debug_game_state()

      false ->
        hand
    end
  end

  def transition(%{round: :flop} = hand) do
    case should_transition?(hand) do
      true ->
        {deck, burn_card} = Poker.Deck.deal(hand.deck)
        {deck, turn} = Poker.Deck.deal(deck)

        %{
          hand
          | round: :turn,
            board: hand.board ++ [turn],
            burn: hand.burn ++ [burn_card],
            deck: deck
        }
        |> debug_game_state()

      false ->
        hand
    end
  end

  def transition(%{round: :turn} = hand) do
    case should_transition?(hand) do
      true ->
        {deck, burn_card} = Poker.Deck.deal(hand.deck)
        {deck, river} = Poker.Deck.deal(deck)

        %{
          hand
          | round: :river,
            board: hand.board ++ [river],
            burn: hand.burn ++ [burn_card],
            deck: deck
        }
        |> debug_game_state()

      false ->
        hand
    end
  end

  def transition(%{round: :river} = hand) do
    case should_transition?(hand) do
      true ->
        # Determine winner in a showdown
        players_with_hands =
          hand
          |> players_in_action()
          |> Enum.reduce(Map.new(), fn player, map ->
            map
            |> Map.put(player, Poker.Hand.value(Map.get(hand.cards, player) ++ hand.board))
          end)

        player_hands =
          players_with_hands
          |> Enum.map(fn {_player, hand} -> hand end)

        winning_hands = Poker.Hand.winner(player_hands)

        count = length(winning_hands)
        split = pot(hand) / count

        winners =
          players_with_hands
          |> Enum.filter(fn {_player, hand} ->
            hand in winning_hands
          end)
          |> Enum.reduce(Map.new(), fn {player, hand}, map ->
            map
            |> Map.put(
              player,
              %{
                hand: hand,
                amount: split
              }
            )
          end)

        %{hand | round: :end, winners: winners}
        |> debug_game_state()

      false ->
        hand
    end
  end

  def pot(hand) do
    hand.actions
    |> Enum.reduce(0, fn action, total ->
      total + action.amount
    end)
  end
end