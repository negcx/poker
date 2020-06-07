defmodule Poker.Game.GameServer do
  use GenServer

  alias Poker.Game.{GameState}

  @impl true
  def init(config) do
    {:ok,
     %GameState{
       config: config
     }}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:take_seat, name, buy_in}, _from, state) do
    if name not in state.players do
      {:reply, :ok, state |> GameState.take_seat(name, buy_in)}
    else
      {:reply, :error, state}
    end
  end

  @impl true
  def handle_call({:update_hand, hand}, _from, state) do
    new_state = state |> GameState.update_hand(hand)
    {:reply, new_state, new_state}
  end

  def update_hand(hand) do
    GenServer.call(__MODULE__, {:update_hand, hand})
  end

  def take_seat(name, buy_in) do
    GenServer.call(__MODULE__, {:take_seat, name, buy_in})
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end
end
