# Scoundrel

A single-player roguelike card game built with [LÖVE2D](https://love2d.org/) and Lua. Based on the solo card game *Scoundrel*, where you navigate a dungeon represented by a standard deck of playing cards.

## Features

- Pixel art card sprites with an 8-bit aesthetic
- 17 GLSL shaders for card effects (dissolve, flame, hologram, foil, polychrome, etc.)
- CRT post-processing filter for a retro feel
- Animated background shader
- Undo system to revert actions
- Smooth fade transitions between screens
- Event-driven MVC architecture with an EventBus

## How to Play

**Goal:** Clear all cards from the deck before your health reaches 0.

**Rooms:** Each room deals 4 cards. You must play 3 in any order — the last card carries over.

### Card Types

| Suit | Role | Effect |
|------|------|--------|
| ♥ Hearts | Potions | Heal by the card's value. Only one potion per room. |
| ♦ Diamonds | Weapons | Equip to fight monsters. Power = card value. |
| ♣ Clubs / ♠ Spades | Monsters | Strength = card value (J=11, Q=12, K=13, A=14). |

### Combat

- **No weapon equipped:** Take full monster damage.
- **With weapon (no level):** Take `max(0, monster − weapon)` damage. Weapon level becomes the monster's value.
- **With weapon (has level):** If monster > level, take full damage. Otherwise, take `max(0, monster − weapon)` damage and level becomes the monster's value.
- **Barehand:** Choose to take full damage instead of using your weapon. Toggle via the blade card button.

### Flee

Skip a room — all 4 cards move to the bottom of the deck. You cannot flee two rooms in a row.

## Controls

| Input | Action |
|-------|--------|
| Click a card | Play that card |
| Click the blade | Toggle fight / barehand mode |
| `U` | Undo last action |
| `Escape` | Quit |

## Getting Started

### Prerequisites

- [LÖVE2D](https://love2d.org/) 11.x or later

### Running the Game

```bash
# Clone the repository
git clone <repository-url>
cd Scoundrel

# Run with LÖVE
love .
```

On macOS you can also drag the project folder onto the LÖVE application.

## Project Structure

```
main.lua                  — Composition root, wires all modules
src/
  Core/
    AssetManager.lua      — Centralized asset loading (textures, fonts, shaders)
    EventBus.lua          — Publish/subscribe event system
    constants.lua         — Game configuration values
    utils.lua             — Utility functions
  Controller/
    game.lua              — Game controller, processes actions via EventBus
    playerAction.lua      — Action definitions (Play, Skip, Next, Undo)
    stateStack.lua        — View state stack manager
  Model/
    card.lua              — Card (suit + value)
    deck.lua              — Deck of 52 cards with shuffle/draw
    gameState.lua         — Core game logic and state
    player.lua            — Player health and weapon/armor
    room.lua              — Current room of 4 cards
  View/
    buttonView.lua        — Clickable UI button
    cardView.lua          — Card rendering with shader effects
    deckView.lua          — Deck pile rendering
    states/
      gameView.lua        — Main gameplay screen
      endGameView.lua     — Win/lose screen
      transitionView.lua  — Fade transition overlay
lib/
  push.lua                — Resolution-independent rendering
  timer.lua               — Tweens and timers
resources/                — Sprites and fonts
shaders/                  — GLSL fragment shaders
```

## Architecture

The codebase follows an **MVC** pattern with event-driven communication:

- **Model** — Pure game state with no knowledge of Views or Controllers.
- **View** — Renders state and publishes user actions to the EventBus.
- **Controller** — Subscribes to actions, updates the Model, and publishes state-change events back to Views.

All modules are wired together in `main.lua` (the composition root). See [documentation.md](documentation.md) for a detailed architectural breakdown.

## Built With

- [Lua](https://www.lua.org/) — Programming language
- [LÖVE2D](https://love2d.org/) — 2D game framework
- [push](https://github.com/Ulydev/push) — Resolution-independent rendering
- [timer](https://github.com/vrld/hump) — Tweens and delayed calls