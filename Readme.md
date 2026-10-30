# Scoundrel

A single-player roguelike card game built with [LÖVE2D](https://love2d.org/) and Lua. Based on the solo card game *Scoundrel*, where you navigate a dungeon represented by a standard deck of playing cards.

**[Play it in your browser](https://pablof27.github.io/Scoundrel/)**

## Features

- Three difficulty levels (**Easy**, **Normal**, **Difficult**), chosen in Settings and applied to every new run
- Home screen with an illustrated **How to Play** tutorial and **Settings** (difficulty, music and sound volume, fullscreen, CRT effect, screen shake, animation speed, card back, FPS counter) saved between sessions
- Procedurally generated audio: a looping dungeon soundtrack and every sound effect are synthesized in code at startup (no audio files)
- Balatro-style card feel: spring physics, "juice" pops, idle sway, 3D tilt towards the mouse, dealing/flipping/burning animations, particles and screen shake
- One-click play with previews: hovering a card shows exactly what it will do (damage, healing, weapon reach) on the card's action tabs, in the health bar and in a hint line
- Explicit **WEAPON** / **FISTS** choice for monsters, a **FLEE** button that explains why it is unavailable, and the next room is dealt automatically
- Run stats panel (health, room, cards left, time, difficulty, monsters and bosses slain, damage taken/blocked, potions, weapons, rooms fled)
- End-of-run summary with the official Scoundrel scoring and your personal best (set by Difficult runs)
- Undo for the cards resolved in the current room
- Pixel art card sprites, GLSL shaders (card tilt + dissolve, animated background, CRT post-processing)
- Event-driven MVC architecture with an EventBus

## How to Play

**Goal:** Make it through the dungeon before your health (20) reaches 0. On **Difficult** you must resolve every card; on **Easy** and **Normal** you escape once the dungeon can't fill another room (see [Difficulty](#difficulty)).

**Rooms:** Each room deals 4 cards. Resolve 3 of them in any order — the 4th stays and becomes part of the next room, which is dealt automatically. On Difficult, in the final room (empty dungeon) every remaining card must be resolved.

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
- **Weapon reach:** Once a weapon has slain a monster, it can only be used against monsters weaker than the last one it slew (on Easy, also as strong as it). You can always fight barehanded to keep the weapon fresh.

### Flee

Before resolving any card of a room you may flee: its 4 cards go to the bottom of the dungeon and a new room is dealt. You cannot flee two rooms in a row.

### Difficulty

Choose it in **Settings**; it applies from the next run (the sidebar and the end-of-run summary show the difficulty of the current one).

| Difficulty | End of the run | Weapon reach | Best score |
|------------|----------------|--------------|------------|
| **Easy** | You escape when the room needs refilling and the dungeon has too few cards left to fill it | Monsters weaker than **or as strong as** the last one slain | No |
| **Normal** | Same as Easy | Monsters weaker than the last one slain | No |
| **Difficult** (default) | You escape once every card has been resolved — the classic rules | Monsters weaker than the last one slain | Yes |

With the 44-card dungeon, Easy and Normal runs end with one card left in the room and one in the dungeon.

### Score

- **Escaped:** your remaining health (plus the potion's value if your last card was a potion drunk at full health).
- **Died:** your health minus the value of every monster left in the dungeon.
- Only **Difficult** runs can set a new best score; every run counts towards runs played and escapes.

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

### Web Version

Every push to `main` builds the game with [love.js](https://github.com/Davidobot/love.js) and publishes it to GitHub Pages ([deploy-web.yml](.github/workflows/deploy-web.yml)). This needs **Settings → Pages → Source** set to **GitHub Actions** in the repository.

To build it locally (needs Node.js and `zip`):

```bash
web/build.sh                          # outputs dist/web
python3 -m http.server -d dist/web    # then open http://localhost:8000
```

The web version uses love.js's compatibility mode, because GitHub Pages can't send the headers its threaded mode needs. Keep in mind:

- It runs PUC Lua 5.1, not LuaJIT: `goto` and other LuaJIT extensions break it. The workflow checks the syntax with `luac5.1` before deploying.
- `love.thread` is unavailable, so the music is rendered on the main thread while the game loads.
- The page owns the window: the game has no Quit button or Fullscreen setting there, and the page has its own fullscreen button.

## Project Structure

```
main.lua                  — Composition root, wires all modules and resolves screen navigation
src/
  Core/
    AssetManager.lua      — Asset loading (textures, baked card atlas, fonts, shaders, audio)
    font.lua              — Fonts rasterized at the screen's pixel density, so text stays sharp at any size
    audio.lua             — Plays sound effects and the music loop at the chosen volumes
    synth.lua             — Tiny offline synthesizer (oscillators, filtered noise, echo)
    sounds.lua            — Sound effect recipes
    music.lua             — Music loop composition (rendered in a background thread)
    EventBus.lua          — Publish/subscribe event system
    constants.lua         — Game configuration values (including the difficulty levels and their rules)
    settings.lua          — User preferences, including the difficulty (persisted)
    records.lua           — Lifetime records: runs, wins, best score of Difficult runs (persisted)
    storage.lua           — Safe key/value persistence in the save directory
    utils.lua             — Utility functions
  Controller/
    game.lua              — Game controller, processes actions via EventBus, undo history
    playerAction.lua      — Action definitions (Play, Skip, Next, Undo)
    stateStack.lua        — Screen/overlay stack manager
  Model/
    card.lua              — Card (suit + value)
    deck.lua              — Deck of 44 cards with shuffle/draw
    gameState.lua         — Core rules (per difficulty), previews, run stats and scoring
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
  push.lua                — Resolution-independent rendering (modified to render at the screen's pixel density)
  timer.lua               — Tweens and timers
resources/                — Sprites and fonts
shaders/                  — GLSL fragment shaders (card.fs: tilt + dissolve)
web/
  build.sh                — Builds the web version into dist/web with love.js
  index.html              — Page hosting the web version
.github/workflows/
  deploy-web.yml          — Publishes the web version to GitHub Pages on every push to main
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
- [love.js](https://github.com/Davidobot/love.js) — LÖVE for the web
- [push](https://github.com/Ulydev/push) — Resolution-independent rendering
- [timer](https://github.com/vrld/hump) — Tweens and delayed calls