defmodule Poker.Game.GameState do
  use TypedStruct

  typedstruct do
    field :config, Poker.Game.Config.t(), enforce: true
    field :players, [String.t()], default: []
    field :stacks, %{String.t() => float()}, default: %{}
    field :hand, Poker.Game.GameHand.t(), default: nil
    field :previous_hand, Poker.Game.GameHand.t(), default: nil
  end

  def take_seat(state, name, buy_in) do
    state
    |> Map.update!(:players, &([name] ++ &1))
    |> Map.update!(:stacks, &Map.put_new(&1, name, buy_in))
    |> game_transition()
  end

  def start_game(state) do
    %{
      state
      | hand:
          Poker.Game.GameHand.new(
            state.config,
            Poker.Deck.new() |> Enum.shuffle(),
            state.players,
            state.stacks
          )
    }
  end

  def update_hand(state, hand) do
    state
    |> Map.put(:hand, hand)
    |> game_transition()
  end

  def game_transition(%{hand: nil, players: players} = state) when length(players) >= 2 do
    state |> start_game()
  end

  def game_transition(%{hand: nil, players: players} = state) when length(players) < 2 do
    state
  end

  def game_transition(%{hand: %{round: :end}} = state) do
    # Move the button
    [new_dealer | tail] = state.players

    previous_hand = state.hand

    state =
      state
      |> Map.put(:players, tail ++ [new_dealer])
      # Update the stacks
      |> Map.put(:stacks, Map.merge(state.stacks, state.hand.stacks))
      # Reset the hand
      |> Map.put(:hand, nil)
      |> Map.put(:previous_hand, previous_hand)

    # Remove players who have 0 chips
    players_without_chips =
      state.players
      |> Enum.filter(&(Map.get(state.stacks, &1) <= 0))

    state
    |> Map.put(
      :players,
      state.players -- players_without_chips
    )
    |> Map.put(
      :stacks,
      state.stacks
      |> Map.drop(players_without_chips)
    )
    |> game_transition()
  end

  def game_transition(state) do
    state
  end
end
