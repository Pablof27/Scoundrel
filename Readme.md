# Table for One

A library of single-player card games built with [LÖVE2D](https://love2d.org/) and Lua. Every game runs on the same card engine: Balatro-style card animations, procedurally generated audio, menus, tutorials, settings and records. The library currently has:

- **[Scoundrel](#scoundrel)**: the solo roguelike card game by Zach Gage and Kurt Bieg. Make it through a dungeon made from a deck of playing cards.
- **[Lobo (The Wolf)](#lobo-the-wolf)**: the solitaire game by James Ernest (Crab Fragment Labs). Capture the Wolf's cards with yours, hand after hand, and race the Wolf to 100 points.

**[Play it in your browser](https://pablof27.github.io/Scoundrel/)**

## Features

**Library**

- A game selection screen, then a home screen per game with an illustrated **How to Play** tutorial and its records
- **Settings** saved between sessions: each game's own options (Scoundrel's difficulty, Lobo's match length) plus the general ones (music and sound volume, fullscreen, CRT effect, screen shake, animation speed, card back, FPS counter)
- Procedurally generated audio: a looping soundtrack and every sound effect are synthesized in code at startup (no audio files)
- Balatro-style card feel: spring physics, "juice" pops, idle sway, 3D tilt towards the mouse, dealing/flipping/burning animations, particles and screen shake
- Pixel art card sprites, GLSL shaders (card tilt + dissolve, animated background, CRT post-processing)
- Event-driven MVC architecture with an EventBus, where each game is a plug-in module (see [Adding a game](#adding-a-game))

**Scoundrel**

- Three difficulty levels (**Easy**, **Normal**, **Difficult**), chosen in Settings and applied to every new run
- One-click play with previews: hovering a card shows exactly what it will do (damage, healing, weapon reach) on the card's action tabs, in the health bar and in a hint line
- Explicit **WEAPON** / **FISTS** choice for monsters, a **FLEE** button that explains why it is unavailable, and the next room is dealt automatically
- Run stats panel (health, room, cards left, time, difficulty, monsters and bosses slain, damage taken/blocked, potions, weapons, rooms fled)
- End-of-run summary with the official Scoundrel scoring and your personal best (set by Difficult runs)
- Undo for the cards resolved in the current room

**Lobo**

- Select a capture by clicking cards of both hands: its name (**PERFECT**, **SUM**, **SPLIT**, **OVER**) and its exact consequence show before you play it, including when it would win the hand or leave you without a capture
- Cards that can't be part of a capture with your selection are dimmed
- The cub (the face-up top card of the deck) is always visible, and the sidebar counts the cards of each value still hidden in the deck
- Match panel racing to 100 (or 50) points, a ledger of every hand, and an end-of-match summary with your statistics
- **FOLD** asks for a second click, so a misclick never gives a hand away

## How to Play

### Scoundrel

**Goal:** Make it through the dungeon before your health (20) reaches 0. On **Difficult** you must resolve every card; on **Easy** and **Normal** you escape once the dungeon can't fill another room (see [Difficulty](#difficulty)).

**Rooms:** Each room deals 4 cards. Resolve 3 of them in any order — the 4th stays and becomes part of the next room, which is dealt automatically. On Difficult, in the final room (empty dungeon) every remaining card must be resolved.

#### Card Types

| Suit | Role | Effect |
|------|------|--------|
| ♥ Hearts | Potions | Heal by the card's value (max 20). Only one potion per room works; any other is wasted. |
| ♦ Diamonds | Weapons | Equip to fight monsters. Equipping one discards the previous weapon and its slain monsters. |
| ♣ Clubs / ♠ Spades | Monsters | Deal damage equal to their value (J=11, Q=12, K=13, A=14). |

The dungeon has 44 cards: every club and spade, plus hearts and diamonds from 2 to 10.

#### Combat

- **Barehanded (FISTS):** Take the monster's full value as damage.
- **With a weapon:** Take `max(0, monster − weapon)` damage. The monster is stacked on the weapon.
- **Weapon reach:** Once a weapon has slain a monster, it can only be used against monsters weaker than the last one it slew (on Easy, also as strong as it). You can always fight barehanded to keep the weapon fresh.

#### Flee

Before resolving any card of a room you may flee: its 4 cards go to the bottom of the dungeon and a new room is dealt. You cannot flee two rooms in a row.

#### Difficulty

Choose it in **Settings**; it applies from the next run (the sidebar and the end-of-run summary show the difficulty of the current one).

| Difficulty | End of the run | Weapon reach | Best score |
|------------|----------------|--------------|------------|
| **Easy** | You escape when the room needs refilling and the dungeon has too few cards left to fill it | Monsters weaker than **or as strong as** the last one slain | No |
| **Normal** | Same as Easy | Monsters weaker than the last one slain | No |
| **Difficult** (default) | You escape once every card has been resolved — the classic rules | Monsters weaker than the last one slain | Yes |

With the 44-card dungeon, Easy and Normal runs end with one card left in the room and one in the dungeon.

#### Score

- **Escaped:** your remaining health (plus the potion's value if your last card was a potion drunk at full health).
- **Died:** your health minus the value of every monster left in the dungeon.
- Only **Difficult** runs can set a new best score; every run counts towards runs played and escapes.

### Lobo (The Wolf)

**Goal:** Empty the Wolf's hand by capturing its cards with yours. When you can't, lose as little as possible: the Wolf scores the cards left in its hand.

**The deck:** 50 cards, aces (worth 1) to 10 in five suits. Suits don't matter. The fifth suit, gold spades, stands in for the fifth suit of the Postas deck the game was designed for. Each hand deals four cards to the Wolf (top row) and four to you (bottom row). The top card of the deck, **the cub**, is always face up; the cards below it are unknown.

#### Captures

Only you take turns. Each turn you play one of these captures:

| Capture | You play | It takes | Then |
|---------|----------|----------|------|
| **Perfect** | one card | a Wolf card of the same value (9 takes 9) | you take the cub |
| **Sum** | two or more cards | one Wolf card equal to their total (6 + 4 takes 10) | you take the cub |
| **Split** | one card | two or more Wolf cards adding up to it (9 takes 6 + 3) | the Wolf takes the cub |
| **Over** | one card | one smaller Wolf card (9 takes 7) | the Wolf takes one card per point of difference: the cub, then unknown cards |

All the cards involved go to the discard pile.

#### End of a hand

- **The Wolf runs out of cards:** you win the hand and score the cards left in your hand, including the card you drew after your final capture.
- **You fold, or have no capture left:** the Wolf scores the cards left in its hand. Folding early can keep that score low: *the wolf takes small bites*.

Hands are played until you or the Wolf reach **100 points** (or 50, chosen in Settings as the match length).

#### Shuffling

As in the house rules, the deck is only shuffled every third hand (or when it can't deal a hand), so the cards already played tell you what is left: the sidebar counts them for you. If the deck runs out during a hand, the discard pile is shuffled into a new deck.

## Controls

### Scoundrel

| Input | Action |
|-------|--------|
| Hover a card | Preview what it will do |
| Click a card | Resolve it (monsters use your weapon when possible) |
| Click a tab under a card | Resolve it that way (`WEAPON` / `FISTS`) |
| Right-click a monster | Fight it barehanded |
| `FLEE` button | Skip the current room |
| `UNDO` button, `U`, `Backspace`, `Ctrl/Cmd+Z` | Undo the last card resolved in this room |
| `Escape` | Pause menu |

### Lobo

| Input | Action |
|-------|--------|
| Click a card (either row) | Add it to, or remove it from, the selected capture |
| Right-click, `Backspace` | Clear the selection |
| `CAPTURE` button, `Enter`, `Space` | Play the selected capture |
| `FOLD` button (twice) | End the hand: the Wolf scores its cards |
| `NEXT HAND` button, `Enter`, `Space` | Deal the next hand |
| Hover the deck, the piles or the sidebar | Explanations in the panel between the piles |
| `Escape` | Pause menu |

On the library screen, `Left`/`Right` and `Enter` pick a game. `Escape` goes back from a game's home screen to the library, and quits from the library.

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
main.lua                  — Composition root: wires all modules, resolves screen navigation, tracks the game played
src/
  Core/                   — Engine services shared by every game
    AssetManager.lua      — Asset loading (textures, baked card atlas with five suits, fonts, shaders, audio)
    font.lua              — Fonts rasterized at the screen's pixel density, so text stays sharp at any size
    audio.lua             — Plays sound effects and the music loop at the chosen volumes
    synth.lua             — Tiny offline synthesizer (oscillators, filtered noise, echo)
    sounds.lua            — Sound effect recipes
    music.lua             — Music loop composition (rendered in a background thread)
    EventBus.lua          — Publish/subscribe event system
    constants.lua         — Configuration shared by the games (library title, display, layout)
    settings.lua          — User preferences: general options plus the options each game declares (persisted)
    records.lua           — Lifetime records of one game, in its own file (persisted)
    storage.lua           — Safe key/value persistence in the save directory
    utils.lua             — Utility functions
  Controller/
    game.lua              — Runs the state of the game being played: actions, undo history, end detection
    action.lua            — Base class of the games' actions (and the Undo action)
    stateStack.lua        — Screen/overlay stack manager
  Model/
    card.lua              — Card (suit, printed rank and game value)
    deck.lua              — Pile of cards with shuffle/draw
  View/
    anim.lua              — Springs, juice and easing helpers
    ui.lua                — Palette and drawing helpers (boxes, text, wavy titles, icons)
    effects.lua           — Floating texts and particle bursts
    buttonView.lua        — Clickable UI button
    cardView.lua          — Animated card sprite (springs, tilt, flip, dissolve)
    deckView.lua          — Draw pile rendering
    boardView.lua         — Base of the game boards (card views, timers, subscriptions, shake, screen flash)
    states/
      libraryView.lua     — Game selection screen (first screen)
      menuView.lua        — Home screen of a game
      pauseView.lua       — In-game menu overlay
      rulesView.lua       — How to Play tutorial (pages given by the game)
      settingsView.lua    — Settings overlay
      endGameView.lua     — End-of-game summary (content given by the game)
      transitionView.lua  — Fade transition overlay
  Games/
    init.lua              — The games of the library, and the fields every game describes itself with
    Scoundrel/
      init.lua            — Game descriptor (options, records, end-of-run summary...)
      config.lua          — Rule values and difficulty levels
      rules.lua           — How to Play pages
      Model/              — gameState.lua (rules, previews, stats, scoring), player.lua, room.lua
      Controller/         — actions.lua (Play, Flee, Next room)
      View/               — gameView.lua (board), sidebarView.lua (health and run stats)
    Lobo/
      init.lua            — Game descriptor (options, records, end-of-match summary...)
      config.lua          — Deck, dealing and match rules
      rules.lua           — How to Play pages
      Model/              — gameState.lua (match, hands, cub, shuffling, scoring), plays.lua (captures)
      Controller/         — actions.lua (Capture, Fold, Next hand)
      View/               — gameView.lua (table), sidebarView.lua (match, deck tracker, ledger)
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

All modules are wired together in `main.lua` (the composition root). The engine (`src/Core`, `src/Controller`, `src/Model`, `src/View`) knows nothing about any particular game: each game lives in `src/Games/<Name>/` with its own model, actions and board, and describes itself to the shared screens through its `init.lua`. See [documentation.md](documentation.md) for a detailed architectural breakdown.

### Adding a game

1. Create `src/Games/<Name>/` with its state (`isOver()`, `isVictory()`, `canUndo`), its actions (`Action.extend`, see `src/Controller/action.lua`) and a board view built on `BoardView`.
2. Write its `init.lua` descriptor (fields documented in `src/Games/init.lua`): name, showcase cards, tutorial pages, options, records, and the functions that create its state and board and summarize a finished game.
3. List it in `src/Games/init.lua`. It then appears in the library with its home screen, tutorial, settings, pause menu and end screen.

## Built With

- [Lua](https://www.lua.org/) — Programming language
- [LÖVE2D](https://love2d.org/) — 2D game framework
- [love.js](https://github.com/Davidobot/love.js) — LÖVE for the web
- [push](https://github.com/Ulydev/push) — Resolution-independent rendering
- [timer](https://github.com/vrld/hump) — Tweens and delayed calls