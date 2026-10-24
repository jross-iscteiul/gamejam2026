# Implementation status — 2026-10-24

Code review against `TASKS 1.md`, the root README and `tests/game_logic/README.md`, based on main `24bd67b` plus the timer/health/leaderboard changes on `feature/run-timer-hud`. **Done** means the code exists in this checkout; it does not certify every feature has been playtested or published. Placeholder integration is distinguished from the final planned feature.

## Package 1 — Player

| Requirement | Status | Evidence / remaining work |
|---|---|---|
| Walk, jump, double jump | Done | `characters/player/player.gd` |
| Coyote time and jump buffer | Pending | Current movement checks the floor/air-jump state directly; no coyote/buffer timers |
| Boost, dash and shield API | Done | Methods exist; real paid input control belongs to Package 2 |
| Shooting/projectile and sounds | Done | Player/bullet scenes, six skins and step/jump/shot audio |
| Health, immunity, death, checkpoints, respawn | Done | Shared Health/Hurtbox, death tween and checkpoint respawn |
| Knockback | Done | `apply_knockback()` and hazard knockback support |
| Camera smoothing | Done | Player Camera2D |
| Screen shake | Partial | Boss-trigger camera shake exists; no general player hit/death shake found |
| Eyes-closing game-over animation | Pending | Current death animation is the falling body tween |

## Package 2 — JARVIS

| Requirement | Status | Evidence / remaining work |
|---|---|---|
| Spawn in levels, follow lag, floating bob, facing/tilt | Done | `characters/jarvis/`, `levels/shared/level.gd`, `tests/jarvis/` |
| Auto-shooting scaled by tokens | Pending | Follow controller explicitly leaves shooting for later |
| Paid dash, shield and jump-boost input | Pending | Economy/player APIs exist, but no JARVIS ability controller yet |
| Speech bubbles using Dialogue | Pending | HUD displays existing `jarvis_say` lines; JARVIS has no bubble |
| Moods, faces and hostile mode | Pending | Current Body is a static code-drawn orb; global hostile flag is available |
| Disabled appearance at zero trust | Done | Tint follows `jarvis_enabled_changed`; future attacks/abilities still need the same gate |
| Voice, shot and ability sounds | Pending | No JARVIS audio nodes/streams found |

## Package 3 — Logic, HUD and placement

| Requirement | Status | Evidence / remaining work |
|---|---|---|
| Shared damage, collision-team filtering, immunity, lethal hazards and kill source | Done | `components/damage/`; pits and hazard Hitboxes use the agreed interfaces |
| Economy, feeding, per-level decay, zero-trust gate and kill doubt | Done | `autoload/game_state.gd`; JARVIS still needs its future attack/ability integration |
| Small/big pickups and pickup sound | Done | `objects/token/`, original coin drawing and chimes |
| Main menu → intro → levels 1–4 | Done | Existing menu, crawl and door transitions |
| Boss → credits | Pending | Boss arena/trigger exists, but actual boss and credits endpoint do not |
| Trust, tokens, player health and boss HUD | Done | `ui/hud/hud.gd`; player health is now a bottom bar; boss bar consumes the agreed signals |
| Main/pause/settings, saved volume and touch preference | Done | `ui/menus/`, mobile multi-touch pads |
| Enemy/token placements in four entity scenes | Done with placeholders | Package 3 robots patrol/shoot/drop tokens; final Package 4 enemies can replace them |
| Story intro/twist cutscenes | Deferred | Existing text crawl is not the planned story/twist sequence; previously excluded from this work |
| UI sounds | Done | `ui/shared/game_ui.gd` |
| Timer, splits, deaths, practice exclusion and local PB | Done | `autoload/run_clock.gd`; finish uses the real `boss_defeated` event |
| Online leaderboard client/API/Docker files | Implemented, not deployed | `autoload/leaderboard_client.gd`, `server/leaderboard/`; disabled until homelab deployment |
| Live itch.io leaderboard / genuine full-game completion | Pending | Deploy the API, enable config, finish the boss and test inside the actual itch.io iframe |

## Package 4 — Enemies and boss

| Requirement | Status | Evidence / remaining work |
|---|---|---|
| Sentinel, Bomber, Kamikaze | Pending | No production enemy controllers/scenes found in `characters/enemies/` |
| Projectiles, explosions, hit flash, kill events | Partial | Shared damage and Package 3 test robot/projectile/flash/kill events exist; production enemy/explosion implementation is still needed |
| Arena entry | Partial | Level 4 locks the gate/camera at a trigger; planned fall from the impossible gap is not implemented |
| Boss phases, weak points, barrages, missiles, shield regeneration | Pending | Level 4 still contains `BossSpawn` with a placeholder label |
| Boss health/defeat events | Interface ready | Signals/HUD/timer listeners exist; no real boss emits them |
| Enemy/boss audio and boss music | Pending | Current level soundtrack is not a dedicated boss implementation |

## Package 5 — Levels

| Requirement | Status | Evidence / remaining work |
|---|---|---|
| Tileset, four levels, parallax backgrounds | Done | Generated level scenes and three-layer city backgrounds |
| Moving platforms | Done | `objects/platforms/`, existing ride tests |
| Falling/one-way platforms | Pending | No implementations found |
| Hazards | Partial against original list | Pits, lasers, lava, toxic pools, blades and hammers exist; no spike implementation found |
| Checkpoints and exits | Done | Shared checkpoint/door scenes; exits emit `level_completed` |
| Progression gates and final impossible gap | Partial | Movement/lever gates and arena lock exist; shield-dependent route/final boost refusal gap still need integration |
| Gambling/quest/easter-egg spots | Not explicitly marked | No extras scenes or reserved markers found; empty geometry alone does not implement those hooks |
| Level soundtrack | Done | Looping Music-bus track persists across levels |
| Ambience and environment/hazard sounds | Pending | No separate ambience/hazard audio implementation found |
| Web export and CI | Done | `export_presets.cfg`, GitHub Actions; same web files can be zipped for itch.io |
| Published itch.io page and device playtest | Not verified here | Requires checking the actual hosted page/build |

## Package 6 — Extras, dialogue and credits

| Requirement | Status | Evidence / remaining work |
|---|---|---|
| Dialogue API and initial roast lines | Stub | `autoload/dialogue.gd` has a few category placeholders, without per-level content |
| Gambling station/wheel/odds/limits | Pending | No gameplay scenes/scripts found |
| Side quests, memory chips and bets | Pending | No gameplay scenes/scripts found |
| Per-level, quest, gambling, death and twist dialogue | Partial | Existing basic kill/death/gambling/low-trust lines only |
| Easter eggs and scrolling team credits | Pending | `credits/ASSETS.md` exists; no playable extras or credits scene |
| Wheel/quest/secret sounds | Pending | No implementations found |

## Integration work still needed

1. Complete JARVIS attacks/abilities and replace test robots with the final enemy scenes.
2. Implement the boss and its real victory event; wire the final gap/twist and credits when those packages are ready. The timer/leaderboard must not finish on the arena placeholder.
3. Deploy the prepared leaderboard app to the homelab, configure the actual itch.io iframe origin, enable `leaderboard.cfg`, then test public score submission. Names/times are client-reported; replay/server validation would be separate anti-cheat work.
4. Complete the remaining Package 1/5 movement/platform features and planned extras, or explicitly agree to cut them for the jam.
5. Finish a full playthrough/balance pass, mobile/browser testing, and outstanding asset attribution checks in `credits/ASSETS.md` (including the existing Freepik TBD entry).

Fresh verification on this branch: Package 3, touch controls, run-clock/HUD, offline leaderboard client, player movement, level flow, moving platforms, JARVIS follow, background/music, hazard placement and individual hazard suites pass. The movement-gate suite now passes **16/16**; the earlier level 1 tunnel failure no longer reproduces on the current levels. These checks are included in CI, together with the Node API tests. Hazard fairness runs, a complete final-game playthrough, and physical-phone/itch.io deployment tests are not claimed by this review.
