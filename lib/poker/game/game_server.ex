defmodule Poker.Game.GameServer do
  use GenServer

  alias Poker.Game.{GameState}

  @impl true
  def init(config) do
    {:ok,
     %GameState{
       players: 1..config.seats |> Enum.map(fn _ -> nil end),
       config: config
     }}
  end

  @impl true
  def handle_call(:get_players, _from, state) do
    {:reply, state.players, state}
  end

  @impl true
  def handle_call({:take_seat, player, index}, _from, %{players: players} = state)
      when length(players) > index do
    case Enum.fetch!(players, index) do
      nil ->
        {:reply, :ok, state |> Map.put(:players, List.replace_at(players, index, player))}

      _ ->
        {:reply, {:error, :seat_occupied}, state}
    end
  end

  # @impl true
  # def handle_cast(:start_game, _from, %{state: :waiting_for_players} = state) do
  #   case state.players |> Enum.filter(&(&1 != nil)) |> length do
  #     x when x >= 2 ->
  #       dealer =
  #         state.players
  #         |> Enum.with_index()
  #         |> Enum.filter(fn {player, _index} -> player != nil end)
  #         |> Enum.map(fn {_player, index} -> index end)
  #         |> Enum.shuffle()
  #         |> hd

  #       state =
  #         state
  #         |> Map.put(:dealer, dealer)
  #         |> Map.put(:state, :preflop)

  #       {:noreply, state}

  #     _ ->
  #       {:noreply, state}
  #   end
  # end

  def take_seat(pid, player, index) do
    GenServer.call(pid, {:take_seat, player, index})
  end

  def get_players(pid) do
    GenServer.call(pid, :get_players)
  end

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end
end
