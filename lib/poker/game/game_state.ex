defmodule Poker.Game.GameState do
  use TypedStruct

  typedstruct do
    field :config, Poker.Game.Config.t(), enforce: true
    field :players, [String.t()], default: []
    field :stacks, %{String.t() => float()}, default: %{}
    field :hand, Poker.Game.Gamehand.t(), default: nil
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

    IO.inspect(state.stacks)
    IO.inspect(state.hand.stacks)
    IO.inspect(Map.merge(state.stacks, state.hand.stacks))

    state
    |> Map.put(:players, tail ++ [new_dealer])
    # Update the stacks
    |> Map.put(:stacks, Map.merge(state.stacks, state.hand.stacks))
    # Reset the hand
    |> Map.put(:hand, nil)
    |> game_transition()
  end

  def game_transition(state) do
    state
  end
end
