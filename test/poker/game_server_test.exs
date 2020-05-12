defmodule Poker.GameServerTest do
  use ExUnit.Case, async: true

  # test "Take a Seat" do
  #   {:ok, gs} = GameServer.start_link(%Config{})
  #   assert GameServer.take_seat(gs, %Player{name: "Kyle", stack: 100}, 3) == :ok

  #   assert GameServer.take_seat(gs, %Player{name: "gely", stack: 100}, 3) ==
  #            {:error, :seat_occupied}
  # end

  # test "Start the game" do
  #   {:ok, gs} = GameServer.start_link(%Config{})
  #   GameServer.take_seat(gs, %Player{name: "Kyle", stack: 100}, 2)
  #   GameServer.take_seat(gs, %Player{name: "Gely", stack: 100}, 3)

  #   players = [nil, nil, "Kyle", "Gely", nil, nil]

  #   assert [2, 3] ==
  #            players
  #            |> Enum.with_index()
  #            |> Enum.filter(fn {player, _index} -> player != nil end)
  #            |> Enum.map(fn {_player, index} -> index end)

  #   assert 2 ==
  #            players
  #            |> Enum.with_index()
  #            |> Enum.filter(fn {player, _index} -> player != nil end)
  #            |> Enum.map(fn {_player, index} -> index end)
  #            |> hd
  # end
end
