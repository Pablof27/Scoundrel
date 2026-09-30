# Scoundrel

A single-player roguelike card game built with [LÖVE2D](https://love2d.org/) and Lua. Based on the solo card game *Scoundrel*, where you navigate a dungeon represented by a standard deck of playing cards.

## Features

- Home screen with an illustrated **How to Play** tutorial and **Settings** (fullscreen, CRT effect, screen shake, animation speed, card back, FPS counter) saved between sessions
- Balatro-style card feel: spring physics, "juice" pops, idle sway, 3D tilt towards the mouse, dealing/flipping/burning animations, particles and screen shake
- One-click play with previews: hovering a card shows exactly what it will do (damage, healing, weapon reach) on the card's action tabs, in the health bar and in a hint line
- Explicit **WEAPON** / **FISTS** choice for monsters, a **FLEE** button that explains why it is unavailable, and the next room is dealt automatically
- Run stats panel (health, room, cards left, time, monsters and bosses slain, damage taken/blocked, potions, weapons, rooms fled)
- End-of-run summary with the official Scoundrel scoring and your personal best
- Undo for the cards resolved in the current room
- Pixel art card sprites, GLSL shaders (card tilt + dissolve, animated background, CRT post-processing)
- Event-driven MVC architecture with an EventBus

## How to Play

**Goal:** Resolve every card of the dungeon before your health (20) reaches 0.

**Rooms:** Each room deals 4 cards. Resolve 3 of them in any order — the 4th stays and becomes part of the next room, which is dealt automatically. In the final room (empty dungeon) every remaining card must be resolved.

### Card Types

| Suit | Role | Effect |
|------|------|--------|
| ♥ Hearts | Potions | Heal by the card's value (max 20). Only one potion per room works; any other is wasted. |
| ♦ Diamonds | Weapons | Equip to fight monsters. Equipping one discards the previous weapon and its slain monsters. |
| ♣ Clubs / ♠ Spades | Monsters | Deal damage equal to their value (J=11, Q=12, K=13, A=14). |

The dungeon has 44 cards: every club and spade, plus hearts and diamonds from 2 to 10.

### Combat

- **Barehanded (FISTS):** Take the monster's full value as damage.
- **With a weapon:** Take `max(0, monster − weapon)` damage. The monster is stacked on the weapon.
- **Weapon reach:** Once a weapon has slain a monster, it can only be used against monsters weaker than the last one it slew. You can always fight barehanded to keep the weapon fresh.

### Flee

Before resolving any card of a room you may flee: its 4 cards go to the bottom of the dungeon and a new room is dealt. You cannot flee two rooms in a row.

### Score

- **Escaped:** your remaining health (plus the potion's value if your last card was a potion drunk at full health).
- **Died:** your health minus the value of every monster left in the dungeon.

## Controls

| Input | Action |
|-------|--------|
| Hover a card | Preview what it will do |
| Click a card | Resolve it (monsters use your weapon when possible) |
| Click a tab under a card | Resolve it that way (`WEAPON` / `FISTS`) |
| Right-click a monster | Fight it barehanded |
| `FLEE` button | Skip the current room |
| `UNDO` button, `U`, `Backspace`, `Ctrl/Cmd+Z` | Undo the last card resolved in this room |
| `Escape` | Pause menu (quits from the home screen) |

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
main.lua                  — Composition root, wires all modules and resolves screen navigation
src/
  Core/
    AssetManager.lua      — Asset loading (textures, baked card atlas, fonts, shaders)
    EventBus.lua          — Publish/subscribe event system
    constants.lua         — Game configuration values
    settings.lua          — User preferences (persisted)
    records.lua           — Lifetime records: runs, wins, best score (persisted)
    storage.lua           — Safe key/value persistence in the save directory
    utils.lua             — Utility functions
  Controller/
    game.lua              — Game controller, processes actions via EventBus, undo history
    playerAction.lua      — Action definitions (Play, Skip, Next, Undo)
    stateStack.lua        — Screen/overlay stack manager
  Model/
    card.lua              — Card (suit + value)
    deck.lua              — Deck of 44 cards with shuffle/draw
    gameState.lua         — Core rules, previews, run stats and scoring
    player.lua            — Player health and weapon
    room.lua              — Current room of 4 cards
  View/
    anim.lua              — Springs, juice and easing helpers
    ui.lua                — Palette and drawing helpers (boxes, text, icons)
    effects.lua           — Floating texts and particle bursts
    buttonView.lua        — Clickable UI button
    cardView.lua          — Animated card sprite (springs, tilt, flip, dissolve)
    deckView.lua          — Dungeon pile rendering
    sidebarView.lua       — Health and run stats panel
    states/
      menuView.lua        — Home screen
      gameView.lua        — Main gameplay screen
      pauseView.lua       — In-game menu overlay
      rulesView.lua       — How to Play tutorial
      settingsView.lua    — Settings overlay
      endGameView.lua     — End-of-run summary
      transitionView.lua  — Fade transition overlay
lib/
  push.lua                — Resolution-independent rendering
  timer.lua               — Tweens and timers
resources/                — Sprites and fonts
shaders/                  — GLSL fragment shaders (card.fs: tilt + dissolve)
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