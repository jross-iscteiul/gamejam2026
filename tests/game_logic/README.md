# Package 3

Press **F6** on `play_package3.tscn` for a playable test using the current level 1 and player. Press **F5** for the main menu, existing intro, and levels 1–4. Chapter Select starts any existing level without the intro. Normal HUD controls: **Feed / 3** restores trust, **Esc / P** pauses; Settings changes and saves Master, Music and SFX volume.

**Settings → Touch Controls** is available in the main menu and pause menu. **Auto** (default) detects touch devices; **On** always shows the pads; **Off** hides them. The preference is saved between sessions. Slide a finger along the bottom-left bar to move (left of centre moves left, right moves right, the centre stops), **Jump** supports the existing double jump, **Dash** dashes, and **Use** operates doors/levers. Hold and drag **Aim / Fire** to aim and shoot in any direction while other fingers move or jump. The existing top HUD buttons feed JARVIS and pause. Landscape gives the controls more room. A physical mouse still works on devices with both mouse and touch.

Touch inputs are released on pause, canceled touches, window focus loss, death, disabling the setting and level transitions. The HUD owns the pads; the player has a small `set_touch_input(active, aim_direction, shooting)` adapter to prevent movement-pad touches from becoming mouse shots. Input-map and movement tuning remain unchanged.

The playground adds test-only controls: **T** gives 10 tokens, **F** feeds JARVIS, **Y** sets trust to zero, **K** damages the player, **right click** tests paid shield, **B** buys an extra jump, and **G** toggles a sample boss health bar. The real JARVIS controller does not exist in this checkout; this adapter is only loaded by the playground. Production ability inputs, shooting scaling, and JARVIS appearance remain Package 2's responsibility. The existing player dash stays available as Package 1 implemented it.

## Automated checks

```powershell
godot --headless --path . res://tests/game_logic/test_package3.tscn
godot --headless --path . res://tests/game_logic/test_touch_controls.tscn
```

Checks the economy, immunity, team filtering, real coin and projectile physics, kill source, death/respawn, all four placements, HUD, pause, volume controls and chapter restart. Returns exit code 1 on failure. For optional rendered UI captures under `.godot/`, run the same scene without `--headless` and append `-- --visual`.

The touch suite sends real multi-finger viewport events to the existing level/player and checks movement, jump, dash, aiming/firing, independent finger releases, cancellation, preference persistence and cleanup on pause/focus/death/scene changes. Both suites run in CI. Physical-phone testing is still useful for device-specific browser layout and ergonomics.

Existing level flow, moving-platform and player-movement suites pass. The movement-gate suite passes 15/16: `L1 tunnel pit4 / jump+dash` also fails on the original HEAD checkout under Godot 4.7.2; this is a pre-existing level/player issue. That suite currently prints failures but exits with code 0. The engine also reports a Windows certificate-store error in this sandbox, including on the original checkout; gameplay does not use networking.

## Balance and public API

| Item | Default |
|---|---|
| Player HP | 3 |
| Player shot | 1 damage, 6 shots/second (existing player) |
| Robot HP | 3, editable per instance |
| Robot contact / shot | 1 damage |
| Robot shot | 130 px/second, every 2.8 / 2.5 / 2.2 / 1.9 seconds by level |
| Hit immunity | Player 0.65 s, test robot 0.10 s |
| Respawn immunity | 1 s |
| Dash immunity | Existing dash duration, 0.15 s |
| Shield | Blocks ordinary damage; pits bypass it |
| Small / big coin | 1 / 5 tokens |
| Robot drop | 1 small coin; source preserved in `enemy_killed(enemy, killer)` |
| Feed | 3 tokens → 25 trust, capped at 100 |
| Dash / shield / boost | 1 token / 2 tokens per second / 3 tokens |
| Trust decay | 0.8 / 1.2 / 1.6 / 2.0 per active second in levels 1–4 |
| Kill doubt | 10% / 25% / 40% / 60% in levels 1–4 |

All original `GameState` signals and function signatures remain. Package 2 should check `GameState.jarvis_enabled` (trust > 0 and not hostile), listen to `jarvis_enabled_changed(enabled)`, and call `use_ability(&"dash" / &"shield" / &"boost_jump")` before invoking Player APIs. It returns false without spending if unavailable. Charge shield once per second; check the player can actually perform an ability before charging. `feed_jarvis()` restores trust even at zero. Existing `tokens_changed` and `trust_changed` listeners continue to work. Trust freezes with the scene tree when paused and outside gameplay.

GameState selects existing `Dialogue` lines on kills/deaths and emits `jarvis_say`; Package 2 can render that signal without selecting the same line again. Kill doubt changes the chosen roast, never the real killer credited in `enemy_killed`.

`Health.take_damage(amount, source)` rejects nonpositive damage and emits `damaged`, `changed(current, maximum)` and `died(source)`. `grant_invulnerability(seconds)` is independent of the existing `invulnerable` shield flag. `restore()` refills health; `kill(source)` bypasses immunity. Hurtboxes filter hostile collision layers and deduplicate a contact observed by both areas. Contact hazards can enable `Hitbox.continuous` to hit again after immunity expires. Keep enemy-death emission in the enemy controller (Health does not emit `enemy_killed` itself).

## Ownership and integration

- Package 3 owns the new `level_XX_entities.tscn` scenes. Each contains editable token and robot instances; replace robot PackedScene references with Package 4's real enemies later. Temporary robots and shots live in `ui/placeholder_enemy/`, leaving `characters/enemies/` and `characters/boss/` untouched.
- Each existing level has only one new PackedScene resource and one `Entities` node. A six-line addition to `levels/build_levels.gd` preserves that instance on rebuild. `levels/shared/level_entities.gd` is a new Package 3 bootstrap; it adds one scene-local HUD and starts/stops trust decay.
- `characters/player/player.gd` needed immunity on accepted dashes, a damage flash, health/collision/animation restoration after death, and ignoring HUD clicks when shooting. Its scene and movement tuning are unchanged.
- `project.godot` changes only the startup scene to the new menu. New Game enters the existing intro; doors, gate, camera scripts and all existing transitions are unchanged. The HUD restart deliberately begins a fresh chapter economy to prevent reloading for unlimited coins.
- `credits/ASSETS.md` adds attribution for the bundled open-license pixel font and original procedural coins/sounds. No new external sprite pack is needed.
- Cutscenes, story text, boss implementation, and boss-to-credits routing are deferred as requested. The boss bar already accepts the agreed boss signals. No fake boss or credits endpoint has been added.
