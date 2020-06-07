defmodule PokerWeb.PokerLive do
  use PokerWeb, :live_view

  alias Poker.Game.{GameHand, GameServer}

  @impl true
  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "game")

    {:ok, socket |> assign([name: nil] ++ transform_game_state(GameServer.get_state(), nil))}
  end

  @impl true
  def handle_event("take_seat", %{"buy_in" => buy_in, "name" => name}, socket) do
    buy_in = String.to_integer(buy_in)

    case GameServer.take_seat(name, buy_in) do
      :ok ->
        Phoenix.PubSub.broadcast_from!(
          Poker.PubSub,
          self(),
          "game",
          {:update, GameServer.get_state()}
        )

        {:noreply,
         socket
         |> assign([name: name] ++ transform_game_state(GameServer.get_state(), name))
         |> push_patch(to: Routes.poker_path(socket, :index, u: name))}

      :error ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("fold", _params, socket) do
    handle_action_event(:fold, %{}, socket)
  end

  @impl true
  def handle_event("check", _params, socket) do
    handle_action_event(:check, %{}, socket)
  end

  @impl true
  def handle_event("call", _params, socket) do
    handle_action_event(:call, %{}, socket)
  end

  @impl true
  def handle_event("all_in", _params, socket) do
    handle_action_event(:all_in, %{}, socket)
  end

  @impl true
  def handle_event("bet", %{"amount" => amount}, socket) do
    try do
      amount = String.to_integer(amount)
      handle_action_event(:bet, %{amount: amount}, socket)
    catch
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("raise", %{"amount" => amount}, socket) do
    try do
      amount = String.to_integer(amount)
      handle_action_event(:raise, %{amount: amount}, socket)
    catch
      _ -> {:noreply, socket}
    end
  end

  def handle_action_event(action, params, socket) do
    player = socket.assigns[:name]
    player_turn = socket.assigns[:turn].player
    actions = socket.assigns[:turn].actions |> Enum.map(& &1.action)

    if player == player_turn and action in actions do
      state = GameServer.get_state()

      hand =
        case action do
          :fold -> state.hand |> GameHand.fold(player)
          :call -> state.hand |> GameHand.call(player)
          :check -> state.hand |> GameHand.check(player)
          :all_in -> state.hand |> GameHand.all_in(player)
          :bet -> state.hand |> GameHand.bet(player, params.amount)
          :raise -> state.hand |> GameHand.raise(player, params.amount)
        end

      state = GameServer.update_hand(hand)

      Phoenix.PubSub.broadcast_from!(
        Poker.PubSub,
        self(),
        "game",
        {:update, state}
      )

      {:noreply, socket |> assign(transform_game_state(state, player))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_params(%{"u" => name}, _uri, socket) do
    {:noreply,
     socket |> assign([name: name] ++ transform_game_state(GameServer.get_state(), name))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:update, state}, socket) do
    {:noreply, assign(socket, state |> transform_game_state(socket.assigns[:name]))}
  end

  def transform_game_state(%{hand: nil} = state, name) do
    players =
      state.players
      |> Enum.map(fn player ->
        %{
          player: player,
          action: nil,
          stack: Map.get(state.stacks, player, 0),
          active: true
        }
      end)

    player =
      if name != nil do
        %{
          stack: Map.get(state.stacks, name, 0),
          cards: []
        }
      else
        nil
      end

    [
      players: players,
      game: nil,
      turn: %{player: nil, actions: []},
      player: player,
      config: state.config
    ]
  end

  def transform_game_state(state, name) do
    current_round = state.hand.round

    players =
      state.hand.players
      |> Enum.map(fn player ->
        last_action =
          state.hand.actions
          |> Enum.filter(&(&1.player == player))
          |> Enum.reverse()

        action =
          if length(last_action) > 0 do
            action = last_action |> hd()

            case {action.action, action.round} do
              {a, ^current_round} ->
                %{
                  action: a,
                  amount: state.hand |> GameHand.current_player_bet(name)
                }

              {:all_in, _} ->
                %{
                  action: :all_in,
                  amount: nil
                }

              {:fold, _} ->
                %{
                  action: :fold,
                  amount: nil
                }

              _ ->
                %{
                  action: nil,
                  amount: nil
                }
            end
          else
            %{
              action: nil,
              amount: nil
            }
          end

        %{
          player: player,
          stack: Map.get(state.hand.stacks, player, 0),
          action: action,
          active: name in GameHand.players_in_hand(state.hand)
        }
      end)

    {turn_player, turn_actions} = state.hand |> GameHand.player_turn()

    turn = %{
      player: turn_player,
      actions: turn_actions
    }

    game = %{
      board: state.hand.board,
      pot: state.hand |> GameHand.pot(),
      current_bet: state.hand |> GameHand.current_bet()
    }

    player =
      if name != nil do
        %{
          stack: Map.get(state.hand.stacks, name, 0),
          cards: Map.get(state.hand.cards, name, [])
        }
      else
        nil
      end

    [
      players: players,
      game: game,
      turn: turn,
      player: player,
      config: state.config
    ]
  end

  defp suit_to_color(suit) do
    case suit do
      :spades -> "bg-gray-700"
      :hearts -> "bg-red-700"
      :diamonds -> "bg-blue-700"
      :clubs -> "bg-green-700"
    end
  end

  defp board_card(card) do
    assigns = %{
      color: card.suit |> suit_to_color(),
      rank: Poker.Rank.to_unicode(card.rank)
    }

    ~L"""
    <div class="w-16 h-20 <%= @color %> rounded-lg flex justify-center items-center">
      <span class="text-2xl text-white"><%= @rank %></span>
    </div>
    """
  end

  defp player_state(assigns, nil) do
    ~L"""
    <tr>
      <td></td>
      <td class="player-td">
        <%= @player %>
      </td>
      <td class="player-td text-right">
        <%= @stack %>
      </td>
      <td class="player-td text-center">
      </td>
    </tr>
    """
  end

  defp player_state(assigns, turn_player) do
    assigns =
      assigns
      |> Map.put(:turn_player, turn_player)

    ~L"""
    <tr class="<%= if not @active, do: "text-gray-500" %>
      <%= if @turn_player == @player, do: "font-bold" %>">
      <td>
        <%= if @turn_player == @player do %>
        <i class="fa fa-caret-right"></i>
        <% end %>
      </td>
      <td class="player-td">
        <%= @player %>
      </td>
      <td class="player-td text-right">
        <%= @stack %>
      </td>
      <td class="player-td text-center">
      </td>
    </tr>
    """
  end

  defp render_action(%{action: :fold} = assigns) do
    ~L"""
    <span class="mt-3 w-full inline-flex rounded-md shadow-sm">
      <button type="button" phx-click="fold" class="w-full inline-flex items-center justify-center px-4 py-2 border border-transparent text-base leading-6 font-medium rounded-md text-gray-700 bg-gray-200 hover:bg-gray-300 focus:outline-none focus:border-gray-300 focus:shadow-outline-gray active:bg-gray-300 transition ease-in-out duration-150">
        Fold
      </button>
    </span>
    """
  end

  defp render_action(%{action: :check} = assigns) do
    ~L"""
    <span class="mt-3 w-full inline-flex rounded-md shadow-sm">
      <button type="button" phx-click="check" class="w-full inline-flex items-center justify-center px-4 py-2 border border-transparent text-base leading-6 font-medium rounded-md text-gray-700 bg-gray-200 hover:bg-gray-300 focus:outline-none focus:border-gray-300 focus:shadow-outline-gray active:bg-gray-300 transition ease-in-out duration-150">
        Check
      </button>
    </span>
    """
  end

  defp render_action(%{action: :call} = assigns) do
    ~L"""
    <span class="mt-3 w-full inline-flex rounded-md shadow-sm">
      <button type="button" phx-click="call" class="w-full inline-flex items-center justify-center px-4 py-2 border border-transparent text-base leading-6 font-medium rounded-md text-gray-700 bg-gray-200 hover:bg-gray-300 focus:outline-none focus:border-gray-300 focus:shadow-outline-gray active:bg-gray-300 transition ease-in-out duration-150">
        Call <%= @amount %>
      </button>
    </span>
    """
  end

  defp render_action(%{action: :all_in} = assigns) do
    ~L"""
    <span class="mt-3 w-full inline-flex rounded-md shadow-sm">
      <button type="button" phx-click="all_in" class="w-full inline-flex items-center justify-center px-4 py-2 border border-transparent text-base leading-6 font-medium rounded-md text-gray-700 bg-gray-200 hover:bg-gray-300 focus:outline-none focus:border-gray-300 focus:shadow-outline-gray active:bg-gray-300 transition ease-in-out duration-150">
        All In <%= @amount %>
      </button>
    </span>
    """
  end

  defp render_action(%{action: :bet} = assigns) do
    ~L"""
    <form phx-submit="bet" class="flex flex-col">
      <div>
        <label for="amount" class="mt-3 block text-sm font-medium leading-5 text-gray-700">Bet
        </label>
        <div class="mt-1 relative rounded-md shadow-sm">
          <input id="amount" class="form-input block w-full sm:text-sm sm:leading-5" name="amount" value="<%= @amount %>" />
        </div>
      </div>
      <span class="mt-3 w-full inline-flex rounded-md shadow-sm">
        <button type="submit" class="w-full inline-flex items-center justify-center px-4 py-2 border border-transparent text-base leading-6 font-medium rounded-md text-gray-700 bg-gray-200 hover:bg-gray-300 focus:outline-none focus:border-gray-300 focus:shadow-outline-gray active:bg-gray-300 transition ease-in-out duration-150">
          Bet
        </button>
      </span>
    </form>
    """
  end

  defp render_action(%{action: :raise} = assigns) do
    ~L"""
    <form phx-submit="raise" class="flex flex-col mt-4">
      <div>
        <div class="mt-1 relative rounded-md shadow-sm">
          <input id="amount" class="form-input block w-full sm:text-sm sm:leading-5" name="amount" value="<%= @amount %>" />
        </div>
      </div>
      <span class="mt-1 w-full inline-flex rounded-md shadow-sm">
        <button type="submit" class="w-full inline-flex items-center justify-center px-4 py-2 border border-transparent text-base leading-6 font-medium rounded-md text-gray-700 bg-gray-200 hover:bg-gray-300 focus:outline-none focus:border-gray-300 focus:shadow-outline-gray active:bg-gray-300 transition ease-in-out duration-150">
          Raise
        </button>
      </span>
    </form>
    """
  end
end
