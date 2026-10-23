# Gamejam 2026

A 2D pixel art platformer in Godot 4.7 (GL Compatibility), played in the browser on itch.io. You fight through four levels with JARVIS, an AI sidekick who works for tokens, and it turns out he's the villain.

The full task split per package is in [TASKS 1.md](TASKS%201.md).

## Getting started

1. Install **Godot 4.7** (standard build, not .NET).
2. Clone the repo and open `project.godot`.
3. Create a branch for your package, e.g. `player`, `jarvis`, `levels`.

## Golden rules

- **Stay in your folders.** Never edit another package's scene. Instance it instead.
- **`project.godot` is shared.** Tell the team in chat before changing it (new input actions, autoloads, layers). Keep those commits small and merge them quickly.
- **Don't change signal or function signatures** in `GameState`, `Dialogue` or the damage components without telling everyone. You can add to them, but don't rename or remove anything.
- **Commit `.uid` files.** Godot generates them next to scripts and resources, and other files reference them.
- **Don't commit `.godot/`.** It's already in `.gitignore`.
- **Each package has a test scene** in `tests/` (e.g. `tests/test_player.tscn`) so you can work without the full game.
- Pull and merge `main` often to avoid painful merges at the end.

## Guidelines

### Godot + git

- **Move or rename files only inside Godot's FileSystem panel,** never in Explorer or VS Code. Otherwise references between files break.
- **Don't save other people's scenes.** Godot sometimes rewrites a scene just from opening it. If git shows changes to a file you don't own, discard them.
- **Don't hand-merge `.tscn` or `.tres` conflicts.** Keep one side and redo the other change in the editor.
- **Run the game before merging into `main`.** `main` must always be playable.

### Code style

- **Follow the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):** `snake_case` for files, folders, functions and variables, `PascalCase` for nodes and `class_name`.
- **Use static typing** (`var speed: float`, `func foo() -> void`).
- **"Call down, signal up."** Never reach into another package's nodes with `get_node("../../Player")`. Use groups, `GameState` signals or `@export` references.
- **Put tuning values in `@export` variables** (speed, HP, costs, cooldowns) so balancing can be done in the inspector.

### Workflow

- **Start commit messages with your package,** e.g. `[player] add coyote time` or `[levels] level 2 layout`.
- **Keep branches short-lived.** Merge small pieces often.
- **Use placeholder art** (colored rectangles) until the asset packs are in.
- **Track every asset pack you use** (author, link, license) in `credits/ASSETS.md`. The itch.io page and in-game credits need it.

## Pixel art and display

These are already set in Project Settings. Don't change them without asking the team.

| Setting | Value |
|---|---|
| Base resolution | **1920×1080** (game camera zoom 3 → 640×360 world view) |
| Stretch mode | `canvas_items`, aspect `expand` |
| Default texture filter | **Nearest** (crisp pixels, no blur) |
| Snap 2D transforms to pixel | On |
| Desktop test window | 1280×720 |

**Tile size: 32×32** (Industrial Tileset). The player's `Camera2D` uses zoom `3`, so the screen shows 20×11 tiles. UI and the intro are laid out at 1920×1080.

Pixel art rules:
- **Every sprite and tileset uses the same tile and pixel scale.** Never scale sprites up or down in the editor to make them fit.
- **Use a pixel font** for UI and speech bubbles, with sizes in multiples of its native size.
- **If the camera jitters with smoothing on,** tell the team before turning off pixel snapping.

## Web (itch.io)

The game ships as an HTML5 export, so the browser is the target platform. Things that behave differently in the browser:

- **Test in the browser regularly.** Use the editor's *Remote Debug -> Run in Browser* button. Don't only test on desktop.
- **Audio only starts after the first click or keypress.** The main menu must need a click or key to start. Don't put important sounds before that.
- **Audio bus effects (reverb, delay, etc.) don't work on the web.** Use plain volume only on `Music` and `SFX`.
- **Esc also exits fullscreen in the browser,** so `pause` is bound to both **Esc** and **P**.
- **Keep the build small.** Use `.ogg` for music and ambience, `.wav` for short SFX, and don't import huge textures.
- **Export:** Package 5 owns the Web export preset. Leave *Thread Support* off so it runs on itch.io without extra headers, and set the itch.io embed size to **1280×720** with the fullscreen button enabled.

## Folder structure

| Folder | Owner |
|---|---|
| `autoload/` | Shared (`GameState`: Package 3, `Dialogue`: Package 6) |
| `components/damage/` | Package 3 |
| `characters/player/` | Package 1 - Player |
| `characters/jarvis/` | Package 2 - JARVIS |
| `characters/enemies/`, `characters/boss/`, `levels/boss/` | Package 4 - Enemies & Boss |
| `objects/token/`, `ui/` | Package 3 - Game logic & HUD |
| `levels/level_01`-`level_04`, `objects/platforms/`, `objects/hazards/` | Package 5 - Levels |
| `objects/gambling/`, `objects/sidequests/`, `objects/eastereggs/`, `credits/` | Package 6 - Gambling & roasting |
| `assets/art`, `assets/audio`, `assets/fonts` | Shared asset packs |
| `tests/` | Everyone (one test scene per package) |

## Singletons (autoloads)

These are available everywhere by name. No need to `preload` them.

### `GameState` ([autoload/game_state.gd](autoload/game_state.gd))

Holds the global state and acts as the **event bus**. Emit and listen to signals here instead of connecting nodes directly across packages.

**Variables**

| Name | Type | Notes |
|---|---|---|
| `tokens` | `int` | Setting it emits `tokens_changed`. Never goes below 0. |
| `trust` | `float` | 0-100. Setting it emits `trust_changed`. At 0, JARVIS stops helping. |
| `current_level` | `int` | |
| `jarvis_hostile` | `bool` | `true` after the twist. |

**Functions**

```gdscript
GameState.add_tokens(5)
if GameState.spend_tokens(3):  # returns false if not enough tokens
    player.boost_jump()
GameState.add_trust(-10)
```

**Signals**

| Signal | Emitted by |
|---|---|
| `tokens_changed(tokens: int)` | GameState (automatic) |
| `trust_changed(trust: float)` | GameState (automatic) |
| `enemy_killed(enemy: Node, killer: Node)` | Enemies |
| `player_died` | Player |
| `player_respawned` | Player |
| `level_completed(level: int)` | Level exit |
| `boss_health_changed(current: float, maximum: float)` | Boss |
| `boss_defeated` | Boss |
| `jarvis_say(text: String, mood: String)` | JARVIS / anyone who wants JARVIS to talk |
| `cutscene_finished` | Cutscenes |

```gdscript
# Emitting
GameState.enemy_killed.emit(self, killer)

# Listening
func _ready() -> void:
    GameState.player_died.connect(_on_player_died)
```

### `Dialogue` ([autoload/dialogue.gd](autoload/dialogue.gd))

All JARVIS lines live here. Package 6 owns the content.

```gdscript
var line := Dialogue.get_line("death", GameState.current_level)
GameState.jarvis_say.emit(line, "smug")
```

Unknown categories return a `[placeholder: ...]` string, so you can call any category before its lines are written.

## Interfaces between packages

| Package | Emits / calls | Listens to |
|---|---|---|
| 1 Player | `player_died`, `player_respawned` | - |
| 2 JARVIS | `jarvis_say` | `enemy_killed`, `tokens_changed`, `trust_changed` |
| 3 Game logic | `tokens_changed`, `trust_changed`, `cutscene_finished` | all |
| 4 Enemies & Boss | `enemy_killed`, `boss_health_changed`, `boss_defeated` | - |
| 5 Levels | `level_completed` | - |
| 6 Gambling / Roasting | `add_tokens`, `add_trust` | `player_died`, `enemy_killed` |

### Player API (called by JARVIS)

The player scene's root script must implement:

```gdscript
func dash(direction: Vector2) -> void
func set_shield(active: bool) -> void
func boost_jump() -> void
```

Until the real player exists, JARVIS should test against a dummy player in `tests/`.

## Groups

Add nodes to these groups so others can find them (`get_tree().get_first_node_in_group("player")`):

| Group | Who |
|---|---|
| `player` | Player root |
| `jarvis` | JARVIS root |
| `enemy` | Every enemy and the boss |
| `player_projectile` | Player and JARVIS bullets |
| `enemy_projectile` | Enemy bullets, bombs, missiles |

## Damage system

Anything that can be hit implements `take_damage(amount: float, source: Node)`. `source` is whoever gets the kill credit, which JARVIS uses for roasting.

The shared components live in `components/damage/` (stubs for now, finished by Package 3):

- **`Health`** (Node): `max_health`, `invulnerable`, `take_damage()`. Signals `damaged(amount, source)` and `died(source)`.
- **`Hitbox`** (Area2D): the thing that hurts. Has `damage` and `source` (defaults to the parent).
- **`Hurtbox`** (Area2D): the thing that gets hurt. Point its `health` export at a `Health` node.

Typical setup:

```
Enemy (CharacterBody2D)
├── Health
├── Hurtbox      (health -> Health)
│   └── CollisionShape2D
└── Sprite2D

Bullet (Area2D or Node2D)
└── Hitbox       (damage = 1)
    └── CollisionShape2D
```

## Collision layers

Already named in Project Settings. Pick them by name in the inspector.

| # | Layer | Used by |
|---|---|---|
| 1 | `world` | Tiles, platforms |
| 2 | `player` | Player body and hurtbox |
| 3 | `enemies` | Enemy bodies and hurtboxes |
| 4 | `player_projectiles` | Player and JARVIS bullets |
| 5 | `enemy_projectiles` | Enemy bullets, bombs, explosions |
| 6 | `pickups` | Tokens, items |
| 7 | `hazards` | Spikes, lasers, pits |

**Teams:**
- Player and JARVIS hitboxes sit on layer 4 and mask layer 3 (enemies).
- Enemy and hazard hitboxes sit on layers 5 and 7 and mask layer 2 (player).
- Pickups sit on layer 6 and mask layer 2.

## Input map

Use these action names. Never check raw keys.

| Action | Key |
|---|---|
| `move_left` / `move_right` / `move_up` / `move_down` | A / D / W / S |
| `jump` | Space |
| `shoot` | Left click |
| `shield` | Right click |
| `interact` | E |
| `dash` | Shift or X (keyboard shortcut for `player.dash()`) |
| `pause` | Esc or P |

Dash is also meant to be a double-tap of a move key, detected by JARVIS, which calls `player.dash(direction)`.

## Audio buses

`Master`, `Music` and `SFX`. Set the `bus` property on every `AudioStreamPlayer` (music goes to `Music`, everything else to `SFX`). The settings menu controls these volumes.

## Level scenes

Each level is split into three scenes so three packages can work on it without conflicts:

| Scene | Owner | Contains |
|---|---|---|
| `level_XX.tscn` | Package 5 | Tilemap, platforms, hazards, checkpoints, exit |
| `level_XX_entities.tscn` | Package 3 | Enemies, tokens |
| `level_XX_extras.tscn` | Package 6 | Gambling stations, side quests, easter eggs |

Package 5 instances the other two into the level.

## Levels, intro and tooling (branch `feature/intro-and-levels`)

- **Intro:** `ui/intro/intro.tscn` (main scene). Scrolling text; any key loads `levels/level_01/level_01.tscn`.
- **Levels 1-4:** `levels/level_XX/level_XX.tscn`, generated from the ASCII maps in `levels/build_levels.gd` (legend at the top of that file). Shared level pieces (door, lever, gate, checkpoint, boss trigger, camera zone, tileset) live in `levels/shared/`; moving platforms in `objects/platforms/`, pits in `objects/hazards/`.
  - Rebuild: `godot --headless --path . res://levels/build_levels.tscn`. **This overwrites the four level scenes**, so either edit the ASCII maps or edit the scenes in the editor, not both.
  - The `level_XX_entities.tscn` / `level_XX_extras.tscn` sub-scenes are not created yet.
- **Placeholder player:** `characters/player/playground_player.tscn`: run, double jump, dash, implements `dash()`, `boost_jump()`, `set_shield()`; emits `player_died` / `player_respawned` on pits.
- **Headless tests** (run from the project folder):
  ```
  godot --headless --path . res://tests/test_levels_flow.tscn       # intro -> level 1 -> ... -> boss arena
  godot --headless --path . res://tests/test_level_gates.tscn       # each obstacle needs its move
  godot --headless --path . res://tests/test_moving_platforms.tscn  # riding and stepping off platforms
  godot --headless --path . res://tests/test_player_moves.tscn      # double jump and dash
  ```
