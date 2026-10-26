# Game Jam - Task Split

Team: André, Emanuel, João, Miguel, Pedro, Yuri. One package per person.

Implementation reviewed against the current code on **2026-10-24**: see [done / partial / pending by package](docs/implementation-status.md). Package 3's checklist below records the current implementation; unchecked items are still partial or deferred. Other packages' original requirements remain below for their owners.

## Design decisions

- Player and JARVIS both shoot. JARVIS fires faster/harder the more tokens he has.
- When trust reaches 0, JARVIS stops helping (no shooting, no abilities) until fed tokens.
- Player always has double jump; JARVIS can boost it for tokens.
- Ending: the final gap needs JARVIS's boost, he refuses, you fall into the boss arena. Twist: JARVIS is the villain.
- Art and sound come from shared asset packs.

## Step 0 - Everyone, at kickoff

- Audio buses: `Master`, `Music`, `SFX`.
- Autoload stubs:
  - `GameState`: `tokens`, `trust`, `current_level`, `jarvis_hostile`
    - Signals: `tokens_changed`, `trust_changed`, `enemy_killed(enemy, killer)`, `player_died`, `player_respawned`, `level_completed`, `boss_defeated`, `boss_health_changed`, `jarvis_say(text, mood)`, `cutscene_finished`
    - Functions: `add_tokens(n)`, `spend_tokens(n) -> bool`, `add_trust(n)`
  - `Dialogue`: `get_line(category, level)` returning placeholder lines
- Conventions:
  - Groups: `player`, `jarvis`, `enemy`, `player_projectile`, `enemy_projectile`
  - Damage: anything hittable has `take_damage(amount, source)` (system owned by Package 3)
  - Player API (called by JARVIS): `dash(direction)`, `set_shield(active)`, `boost_jump()`
  - Collision layers: world, player, enemies, player projectiles, enemy projectiles, pickups, hazards
  - Input map: WASD move, Space jump, Left click shoot, Right click shield, E interact, Esc pause
  - Each package owns its folders; never edit another package's scene, only instance it
  - Each package has its own test scene in `tests/`

## Package 1 - Player

Owner: TBD
Owns: `characters/player/`

- Walk, jump, double jump, coyote time, jump buffer
- `boost_jump()`, `dash(direction)`, `set_shield(active)`
- Basic shot and projectile
- Health, invincibility frames, knockback, death, checkpoints, respawn
- Camera with smoothing and screen shake
- Game over animation (eyes closing)
- Player sounds

## Package 2 - JARVIS

Owner: TBD
Owns: `characters/jarvis/`

- Follows the player with lag and floating bob
- Auto-shooting that scales with tokens
- Input detection for dash (double-tap WASD), shield (right click) and jump boost; calls player API
- Speech bubbles reading from `Dialogue`
- Moods and faces, including hostile mode
- Disabled look and behaviour when trust is 0
- JARVIS sounds: voice blips, shots, abilities

## Package 3 - Tokens, game logic, HUD & enemy placement

Owner: TBD
Owns: real `GameState`, `objects/token/`, `ui/`, scene manager

- Damage system:
  - [x] Shared `Health`, `Hitbox`, `Hurtbox` components in `components/damage/`
  - [x] Teams via collision layers: player/JARVIS hits only enemies, enemies/hazards hit only the player
  - [x] Invincibility frames, shield/dash invulnerability, instant-kill pits
  - [x] Kill credit (`source`) so JARVIS can roast whoever got the kill
  - [x] HP and damage balance table in `tests/game_logic/README.md`
- Game logic:
  - [x] Token costs and `spend_tokens`
  - [x] Trust decay per level, feeding, disabled-state API at 0; Package 2 must apply it to future shooting/abilities
  - [x] Kill-doubt chance growing per level
- [x] Tokens: small and big pickups
- [ ] Full scene flow: menu -> intro -> levels 1-4 works; actual boss -> credits still needs Packages 4/6
- [x] HUD: top trust bar, token counter, boss-signal health bar, bottom player health bar
- [x] Menus: main menu, pause, settings (volume and touch controls)
- [x] Enemy and token placement in levels 1-4 (in `level_XX_entities.tscn`); robots remain replaceable placeholders
- [ ] Intro and twist cutscenes: existing text crawl only; story cutscenes deferred
- [x] UI and token pickup sounds
- [x] Full-run timer, level splits, deaths and saved personal best; pause stops time, chapter select/restarts are practice
- [x] Self-hosted leaderboard client, API, SQLite persistence and Docker deployment files
- [x] Level 4 boss: the Foreman robot (volleys, ground slam, minion doors) that hands the fight to a turncoat JARVIS for the last phase
- [x] Deploy leaderboard to `leaderboard-gamejam2026.suricata-lab.com`, verify HTTPS/API connectivity, and enable `leaderboard.cfg`
- [ ] Re-export/upload the enabled game and test the published itch.io build
- [ ] End-to-end full-run score submission after the real boss emits `boss_defeated`

## Package 4 - Enemies & Boss

Owner: TBD
Owns: `characters/enemies/`, `characters/boss/`, `levels/boss/`

- Sentinel: patrols and shoots
- Bomber: drops bombs
- Kamikaze: charges and explodes
- Shared projectiles, explosions, hit flash; emits `enemy_killed`
- Boss:
  - Arena scene, entered by falling from above
  - Phase 1: shield with weak points; each destroyed triggers a fireball barrage; all destroyed opens a damage window
  - Phase 2: homing missiles, faster attacks, shield regenerates
  - Emits `boss_health_changed` and `boss_defeated`
- Enemy and boss sounds, boss music

## Package 5 - Levels

Owner: TBD
Owns: `levels/level_01`-`level_04`, `objects/platforms/`, `objects/hazards/`

- Tileset and parallax background
- Platforms: moving, falling, one-way
- Hazards: spikes, pits, lasers
- Checkpoint positions and level exit emitting `level_completed`
- Level 1: basics. Level 2: dash. Level 3: shield. Level 4: hard mix ending in the impossible gap
- Empty spots for gambling stations, side quests and easter eggs
- Level music, ambience, environment sounds
- Leads export and itch.io page

## Package 6 - Gambling, side quests, roasting, easter eggs & credits

Owner: TBD
Owns: real `Dialogue`, `objects/gambling/`, `objects/sidequests/`, `objects/eastereggs/`, `credits/`

- Gambling: station (press E), wheel UI and animation, odds worsen per level, limited spins
- Side quests, for example:
  - Broken robot asks for tokens and pays back in trust
  - Hidden memory chips restore JARVIS's memories and hint at the twist
  - Bet with JARVIS: "finish this section without dying"
- Roasting: all JARVIS lines in `Dialogue`
  - Per-level lines, kill doubts, gambling, deaths, side quests
  - Twist lines
- Easter eggs: secret rooms, references, hidden JARVIS dialogue
- Credits: scrolling names with a JARVIS roast per team member
- Wheel, side quest and secret sounds

## Interfaces

| Package | Emits / calls | Listens to |
|---|---|---|
| 1 Player | `player_died`, `player_respawned` | - |
| 2 JARVIS | `jarvis_say` | `enemy_killed`, `tokens_changed`, `trust_changed` |
| 3 Game logic | `tokens_changed`, `trust_changed`, `cutscene_finished` | all |
| 4 Enemies & Boss | `enemy_killed`, `boss_health_changed`, `boss_defeated` | - |
| 5 Levels | `level_completed` | - |
| 6 Gambling / Roasting | `add_tokens`, `add_trust` | `player_died`, `enemy_killed` |

## Level scene ownership

- Package 5 owns `level_XX.tscn`.
- Package 3 works in `level_XX_entities.tscn` (enemies, tokens).
- Package 6 works in `level_XX_extras.tscn` (gambling, side quests, easter eggs).
- Package 5 instances both sub-scenes into the level.

## Integration (end)

1. Levels swaps placeholders for the real scenes.
2. Game logic wires the scene manager through every level.
3. Full playthrough and balancing: token costs, wheel odds, trust decay, enemy health, audio levels.
