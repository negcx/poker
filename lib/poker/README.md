# Poker Game
## Game Configuration
* Number of seats
* Small/big blind
* Minimum/maximum buyin
* Turn time

## Game State
* Seats
* Players (Name, Stack, Cards)
* Pot
* Deck / Cards
* Dealer
* Small / Big Blind
* Status
    * Players in hand
    * Preflop
    * Flop
    * Turn
    * River
* Substatus
    * Player turn
    * Current bet
    * Turn timer
    * Player actions for turn
        * Fold
        * Call
        * Timeout
        * Bet/Raise
        * Check
* Current Round
    * Players and Player Bets

## Event Sequence
1. Game Starts with Configuration (Game must be registered)
2. Players go to the Game Page
3. Players take a "seat" at the Game's table
    1. Buyin with chips
    2. Select player name
4. Game Begins (**How is this triggered?**)

## Game Loop
1. Place dealer button
2. Deal cards to players with chips

SELECT ROUND PLAYERS
- All seats where stack > 0 and player is not nil

MOVE BUTTON
- if button is nil, place it randomly
- otherwise move it 1 player to left

deal cards to round players

ACTION: AUTOBET SMALL BLIND
ACTION: AUTOBET BIG BLIND
TURN: PLAYER LEFT OF BIG BLIND

action types:
- :small_blind
- :big_blind
- :fold
- :call
- :check
- :raise
- :bet

3. Preflop betting loop
    1. Player to the left of big blind has the option to fold, call, raise
    2. Repeat until all players have called or folded
4. Postflop - deal community cards
5. Postflop - betting loop
    1. Left of dealer has the option to bet or check (or fold)
    2. Call/check or bet/raise or fold depending on state, repeat until all players have called or folded
6. Turn - deal card
7. Turn - betting loop
8. River - deal card
9. River - betting loop

Repeat, moving dealer button

## Player States
1. Seated with chips
2. Seated, no chips
3. Waiting to join (Seated, with chips)
    1. Waiting for Big Blind
    2. Pay to join next hand


# Todo
* Function to inspect game state to determine whose action it is and what actions are valid
    * Check for correct player turn
    * Check for valid bet sizes based on previous bets, blinds, stack size, etc.
* Prevent invalid actions from being committed to the game state
* Consider refactoring code that uses maps where lists can be used
* Implement edge case for [Rule 43](https://www.pokertda.com/view-poker-tda-rules/). If a player all-ins for an amount less than a full bet, the players after only have the option to call (if they have already acted).