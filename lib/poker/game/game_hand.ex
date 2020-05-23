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
    field :winners, [%{String.t() => %{amount: float(), hand: Poker.Hand.t() | nil}}], default: []
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
    |> debug_game_state()
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

  defp action(hand, %{action: :all_in} = action) do
    %{hand | actions: hand.actions ++ [action]}
    |> update_stack(action.player, -action.amount)
    |> early_transition_to_end()
    |> transition()
  end

  defp action(hand, action) do
    action |> debug_action

    if action.amount >= Map.get(hand.stacks, action.player) do
      all_in(hand, action.player)
    else
      %{hand | actions: hand.actions ++ [action]}
      |> update_stack(action.player, -action.amount)
      |> early_transition_to_end()
      |> transition()
    end
  end

  defp update_stack(hand, player, change) do
    %{hand | stacks: Map.update!(hand.stacks, player, &(&1 + change))}
  end

  @spec small_blind(Poker.Game.GameHand.t()) :: Poker.Game.GameHand.t()
  def small_blind(%__MODULE__{round: :preflop, actions: []} = hand) do
    player = hand.players |> hd

    hand
    |> action(%Action{
      round: :preflop,
      action: :small_blind,
      player: player,
      amount: hand.config.small_blind
    })
  end

  @spec big_blind(Poker.Game.GameHand.t()) :: Poker.Game.GameHand.t()
  def big_blind(%__MODULE__{round: :preflop, actions: actions} = hand)
      when length(actions) == 1 do
    player = hand.players |> Enum.fetch!(1)

    hand
    |> action(%Action{
      round: :preflop,
      action: :big_blind,
      player: player,
      amount: hand.config.big_blind
    })
  end

  def call(hand, player) do
    player_stack = Map.get(hand.stacks, player)

    amount = min(player_stack, current_bet(hand) - current_player_bet(hand, player))

    case amount do
      0 ->
        check(hand, player)

      amount ->
        hand
        |> action(%Action{
          player: player,
          amount: amount,
          round: hand.round,
          action: :call
        })
    end
  end

  def all_in(hand, player) do
    hand
    |> action(%Action{
      player: player,
      amount: Map.get(hand.stacks, player),
      round: hand.round,
      action: :all_in
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

  def current_player_bet(hand, player) do
    hand.actions
    |> Enum.filter(&(&1.round == hand.round))
    |> Enum.filter(&(&1.player == player))
    |> Enum.reduce(0, fn action, total ->
      action.amount + total
    end)
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

  defp raise_difference([prev_bet | tail] = bets, minimum) when length(bets) > 1 do
    [next_bet | small_tail] = tail
    raise_size = next_bet - prev_bet

    if raise_size >= minimum do
      [raise_size] ++ raise_difference(tail, raise_size)
    else
      # This bet is smaller than the minimum
      # skip it in the list
      raise_difference(small_tail, minimum)
    end
  end

  defp raise_difference(bets, _minimum) when length(bets) <= 1 do
    []
  end

  def minimum_raise(hand) do
    # The minimum raise is at least the amount of the most
    # recent raise. This is tricky because we are tracking
    # the total amount the player is putting in the pot,
    # not the amount that makes up the "call" portion and
    # the "raise" portion of a bet.

    # TODO - Deal with all ins
    bets_and_raises =
      hand.actions
      |> Enum.filter(&(&1.round == hand.round))
      |> Enum.filter(&(&1.action in [:big_blind, :bet, :raise, :all_in]))
      |> Enum.map(&max(&1.amount, hand.config.big_blind))
      |> (&([0] ++ &1)).()
      |> raise_difference(hand.config.big_blind)

    max(hand.config.big_blind, List.last(bets_and_raises))
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

  def players_in_hand(hand) do
    players_who_folded =
      hand.actions
      |> Enum.filter(&(&1.action == :fold))
      |> Enum.map(& &1.player)

    hand.players -- players_who_folded
  end

  def players_who_acted(hand, round) do
    hand.actions
    |> Enum.filter(&(&1.round == round))
    |> Enum.filter(&(&1.action not in [:small_blind, :big_blind]))
    |> Enum.map(& &1.player)
    |> MapSet.new()
    |> MapSet.to_list()
  end

  defp should_transition?(hand) do
    # Transition Conditions
    # Players must have acted this round or previously been all in
    # or folded.
    # Players who aren't all in need to have a bet that matches
    # the highest bet made this round.

    all_in_players =
      hand.actions
      |> Enum.filter(&(&1.action == :all_in))
      |> Enum.map(& &1.player)
      |> Enum.uniq()

    folded_players =
      hand.actions
      |> Enum.filter(&(&1.action == :fold))
      |> Enum.map(& &1.player)
      |> Enum.uniq()

    acted_players =
      hand.actions
      |> Enum.filter(&(&1.action not in [:small_blind, :big_blind]))
      |> Enum.filter(&(&1.round == hand.round))
      |> Enum.map(& &1.player)
      |> Enum.uniq()

    turns_remaining =
      hand.players
      |> Kernel.--(all_in_players)
      |> Kernel.--(folded_players)
      |> Kernel.--(acted_players)

    active_players =
      hand.players
      |> Kernel.--(all_in_players)
      |> Kernel.--(folded_players)

    if length(turns_remaining) == 0 or length(active_players) in [0, 1] do
      # If there are players below the current bet who are not all in
      # or folded then they need to act before we move to the next turn.
      players_below_current_bet =
        hand
        |> player_bets()
        |> Enum.filter(fn {_player, action} ->
          action.action not in [:fold, :all_in]
        end)
        |> Enum.filter(fn {_player, action} ->
          action.bet < current_bet(hand)
        end)

      case length(players_below_current_bet) do
        0 -> true
        _ -> false
      end
    else
      false
    end
  end

  def debug_game_state(hand) do
    Logger.debug("Round #{hand.round}")

    _ =
      if length(hand.board) > 0 do
        board =
          hand.board
          |> Enum.map(&to_string/1)
          |> Enum.join(" ")

        Logger.debug("Board #{board}")
      end

    case hand.round do
      :new ->
        hand

      :end ->
        _ =
          hand.winners
          |> Enum.map(fn {player, map} ->
            case map.hand do
              nil ->
                Logger.debug("   #{player} won #{map.amount}, all other players folded")

              hand ->
                cards =
                  hand.cards
                  |> Enum.map(&to_string/1)
                  |> Enum.join(" ")

                Logger.debug("   #{player} won #{map.amount} with #{hand.type}, #{cards}")
            end
          end)

        hand

      _ ->
        Logger.debug("Players")

        _ =
          hand
          |> players_in_hand()
          |> Enum.map(fn player ->
            stack = Map.get(hand.stacks, player)
            cards = Map.get(hand.cards, player, [])
            cards = cards |> Enum.map(&to_string/1) |> Enum.join(" ")

            Logger.debug("   #{player} #{stack} #{cards}")
          end)

        Logger.debug("")

        hand
    end
  end

  def debug_action(action) do
    Logger.debug("   Action #{action.player} #{action.action} #{action.amount}")

    action
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
        |> transition()

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
        |> transition()

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
        |> transition()

      false ->
        hand
    end
  end

  def transition(%{round: :river} = hand) do
    if should_transition?(hand) do
      # Split Pot Algorithm
      #
      # Create a pot out of the lowest bet amount,
      # group all players there with that bet amount.
      # Determine the winner of that pot.
      # Remove that amount from everyone's bets and repeat.

      # We need to include ALL player bets as they count toward
      # the pot totals.
      all_player_bets =
        hand.actions
        |> Enum.group_by(& &1.player)
        |> Enum.reduce([], fn {player, actions}, acc ->
          total_bets =
            actions
            |> Enum.reduce(0, fn action, total ->
              total + action.amount
            end)

          acc ++
            [
              %{
                player: player,
                bet: total_bets,
                action: List.last(actions).action,
                hand: Poker.Hand.value(Map.get(hand.cards, player) ++ hand.board)
              }
            ]
        end)

      # All the current bets in order
      list_of_bets =
        all_player_bets
        |> Enum.map(& &1.bet)
        |> Enum.uniq()
        |> Enum.sort()

      # Reduce each bet by the previous round bets
      pot_bets = list_of_bets |> list_subtract()

      # Combine the current bet for each round with the total bet required
      # to enter that round in a single map, each entry representing a pot.
      winners =
        0..(length(list_of_bets) - 1)
        |> Enum.map(fn i ->
          %{total_bet: Enum.fetch!(list_of_bets, i), pot_bet: Enum.fetch!(pot_bets, i)}
        end)
        # For each pot, gather all the players who participate in that pot
        # and calculate the total of that pot.
        |> Enum.reduce(Map.new(), fn pot, map ->
          player_bets = all_player_bets |> Enum.filter(&(&1.bet >= pot.total_bet))

          map
          |> Map.put(
            %{
              total_bet: pot.total_bet,
              pot_bet: pot.pot_bet,
              total_pot: pot.pot_bet * length(player_bets)
            },
            player_bets
          )
        end)
        # Determine the winner(s) of each pot.
        |> Enum.map(fn {pot, players} ->
          winning_hands =
            players
            |> Enum.filter(&(&1.action != :fold))
            |> Enum.map(& &1.hand)
            |> Poker.Hand.winner()

          players
          |> Enum.filter(&(&1.hand in winning_hands))
          |> Enum.reduce([], fn p, acc ->
            acc ++
              [%{player: p.player, hand: p.hand, amount: pot.total_pot / length(winning_hands)}]
          end)
        end)
        |> List.flatten()
        # Combine all the different pots into a map of winners
        # and their winnings.
        |> Enum.reduce(Map.new(), fn winner, map ->
          map
          |> Map.update(
            winner.player,
            %{amount: winner.amount, hand: winner.hand},
            &%{&1 | amount: &1.amount + winner.amount}
          )
        end)

      %{hand | round: :end, winners: winners}
      |> debug_game_state()
    else
      hand
    end
  end

  def transition(%{round: :end} = hand) do
    hand
  end

  def early_transition_to_end(hand) do
    if length(players_in_hand(hand)) == 1 do
      winner = hand |> players_in_action |> hd
      winners = %{winner => %{amount: pot(hand), hand: nil}}

      %{hand | round: :end, winners: winners}
      |> update_stack(winner, pot(hand))
      |> debug_game_state()
    else
      hand
    end
  end

  def total_bet(hand, player) do
    hand.actions
    |> Enum.filter(&(&1.player == player))
    |> Enum.reduce(0, fn action, total ->
      total + action.amount
    end)
  end

  @spec list_subtract([integer()]) :: [integer()]
  def list_subtract([head | tail] = bets) when length(bets) > 1 do
    [head] ++ list_subtract(tail |> Enum.map(&(&1 - head)))
  end

  def list_subtract(bets) when length(bets) == 1 do
    bets
  end

  def pot(hand) do
    hand.actions
    |> Enum.reduce(0, fn action, total ->
      total + action.amount
    end)
  end

  def player_turn(hand) do
    turns =
      hand.actions
      |> Enum.filter(&(&1.round == hand.round))
      |> Enum.filter(&(&1.player in players_in_action(hand)))
      |> Enum.map(& &1.player)

    # We can technically have infinite turns so we need a list
    # at least longer than turns
    players =
      hand
      |> players_in_action()
      |> Stream.cycle()
      |> Enum.take(length(turns) + 1)

    (players -- turns) |> hd
  end
end
