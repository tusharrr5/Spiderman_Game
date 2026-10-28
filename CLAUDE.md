# CLAUDE.md — Web-Slinger: Night Patrol

## 1. Environment
- **Engine**: Godot **4.7.2 stable** (`config_version=5`, GL Compatibility renderer on desktop, mobile and web).
- **Godot binary on this Mac**: `/Users/tusharbhojwani/Downloads/Godot.app/Contents/MacOS/Godot` (the editor may run from an AppTranslocation copy of it; do not hardcode that path).
- **Python**: `python3` from `/Library/Frameworks/Python.framework/Versions/3.14` has Pillow 12 and numpy (used by `tools/`). `/usr/bin/python3` and Homebrew python3 do **not** have Pillow.
- **Export templates**: see section 6. **Android**: no JDK runtime, Android SDK or `adb` installed (section 7).

## 2. Layout
```text
scripts/core/      game_state.gd (autoload GameState: progress + tokens/upgrades/suits/ranks/arena records), audio_manager.gd (Audio),
                   fx.gd (Fx), sprite_animator.gd (grid atlases), combat_camera.gd, post_fx.gd, scoring.gd
scripts/player/    player_controller.gd  (PlayerController state machine)
scripts/combat/    health/hitbox/hurtbox components, web_projectile, enemy_projectile, throwable_object
scripts/enemies/   enemy_base -> normal_enemy (thug), gunner_enemy, drone_enemy; boss_base -> thief_boss, goblin_boss; prototype_boss (Brick)
scripts/versus/    versus_level.gd (1v1 / 3v3 elimination / CPU vs CPU, tag, 99s timer, results), fighter_ai.gd (bot brain, 4 levels)
scripts/levels/    campaign_level.gd, arena_level.gd (gauntlet/survival/daily), level_builder.gd, prototype_level.gd, objects/
scripts/data/      level_registry.gd (ALL chapter data), story_data.gd, sprite_db.gd (GENERATED - do not edit)
scripts/ui/        hud_and_touch.gd, fight_hud.gd, results_panel.gd, dialogue_box.gd, input_diagnostics.gd,
                   menus/ (title, level select, arena_hub, shop, story, credits, ui_kit)
scenes/            menus/*.tscn, levels/campaign_level.tscn + prototype_level.tscn, player, enemies, objects, ui
assets/            sprites/characters (generated strips), backgrounds/<theme>, tiles, props, portraits, story, ui, audio, music
tools/art|audio|capture   asset generators (characters: vol_renderer.py + vol_chars.py + vol_build.py), screenshots, README GIF
tests/             headless_test_runner.gd (launcher), suites/prototype_suite.gd, campaign_suite.gd, combat_suite.gd, versus_suite.gd, compile_check.gd
docs/media/        README screenshots + gameplay.gif
```
Main scene: `res://scenes/menus/title_screen.tscn`. The original prototype level still exists and is used by `prototype_suite`.

## 3. Input
Actions: `move_left/right` (A/D, arrows), `climb_up/down` (W/S, arrows), `jump` (Space), `attack_punch` (J), `attack_kick` (H), `web_action` (K), `special_action` (L), `suit_toggle` (C), `dodge` (Shift), `pause_game` (Esc). Each key is bound by both keycode and physical keycode.
Fighting inputs reuse these actions (no new actions): hold `climb_down` on the ground = BLOCK (parry = block within `parry_window` before a hit), hold `attack_punch` = heavy, `dodge` then punch = dash strike, `special_action` = SP1 / `climb_up`+special = SP2 / `climb_down`+special = SP3 (needs 1/2/3 meter bars; a nearby crate is thrown instead).
- Keys are player-remappable: `KeyBindings` (scripts/core/key_bindings.gd) snapshots the project.godot keys as defaults, applies `user://keybinds.cfg` at startup (GameState._ready) and rewrites only InputEventKey events (2 slots per action). UI is `KeyBindPanel` (title CONTROLS & KEYS, PAUSE > KEYS). Hint text uses `{punch}`/`{web}`/`{move}`... tokens filled by `KeyBindings.fill()`; never hardcode key names in hints. Tests set `KeyBindings.save_path` to a scratch file.
- On-screen buttons call `Input.action_press/release` **and** `PlayerController.buffer_action_tap/release` (the shared action interface). Releasing on window focus loss is handled in the HUD, because the engine does not release `action_press` state.
- `PlayerController.input_locked` freezes input during cutscenes.
- **Editor Game tab gotcha**: in 2D/3D Select or Suspend mode, Godot calls `Input.set_disable_input(true)` and `root.set_disable_input_override(true)`. No game code receives input. `Viewport.is_input_disabled()` does NOT report this. The F3 diagnostics overlay detects it (`INPUT_SINGLETON_BLOCKED`) and logs to `user://input_diag_<mode>.log`. The fix is the Game tab's gamepad "Input" toggle; do not add workarounds in game code.
- Verified with real OS keystrokes in a standalone window (2026-10-28): movement, wall climb, ceiling crawl, jump/super jump, web shot/swing and special. On-screen buttons with a real mouse, J/H/Esc, and real mobile touch have **not** been manually verified.

## 4. Gameplay architecture
- Player states: IDLE, RUNNING, JUMPING, FALLING, WALL_CLIMBING, CEILING_CRAWLING, WEB_SWINGING, ATTACKING, HURT, DEFEATED, DODGING, BLOCKING. The collision body is 14×30 with feet at local y=+14.
- Character sprites are pre-rendered 3D-look grid atlases (≤4096 px wide) from `tools/art/vol_build.py`. SpriteDB stores frame px, cols/rows, display `scale` and `feet` offset per sheet (4 texels per game px). Never hand-edit `sprite_db.gd`.
- Guard/parry: `HurtboxComponent.guard` is an optional Callable(damage, knockback, type, attacker) -> damage (<0 cancels). Hitboxes pass `owner_actor` as the attacker on both the area and body paths. Enemies use it to block light attacks (`EnemyBase.GUARDABLE`) unless the attack is in `GUARD_BREAKERS`. Anything that can be parried implements `apply_parry_stun(duration)`.
- Versus fighters are PlayerControllers. A bot has `is_bot=true` and `controller=FighterAI` set BEFORE add_child: it never joins group "player" or reads Input, and the AI feeds `buffer_action_tap` + `is_held`/`move_axis`. `setup_fighter()` sets team groups (`team1`/`team2`, `foe_group`), stats, passive and sheet. Team 2 uses enemy collision layers (body/hurtbox 4, hitbox 16 mask 2). Versus scales HP x1.8 and damage x0.45 (`VersusLevel.HP_SCALE/DMG_SCALE`).
- Versus fighters (`setup_fighter`) get `long_combo` (5-hit chain jab/cross/hook/roundhouse/finisher = steps 1,2,7,8,3), a `FightEffects` child (buffs/debuffs, DoT; halted while `VersusLevel` flow is paused), class from `SpiderRoster.CLASSES` (triangle: +12% / -10%), signature debuff/buff from `SpiderRoster.SIG`, boosts (`boost_attack/defense/crit`) and level bonus. A heavy needs J held continuously since the jab started (`_punch_released`).
- Versus progression lives in GameState: `BOOSTS` + `boosts` inventory, `fighter_xp` / `fighter_level()`, `claim_daily_login()`, `CHALLENGES` + `bump()` / `check_challenges()`; `record_versus(..., fight_stats)` fills `last_versus_rewards` for the results screen.
- Roster data is in `scripts/data/spider_roster.gd`. Variant art is in `tools/art/spiderverse.py` (18 `sv_*` sheets at 3 texels/px; Classic/Symbiote reuse the hero sheets).
- Multi-hit specials use `_hit_schedule` windows. Hitbox deactivation is deferred, so never deactivate and re-activate in the same frame.
- Scoring (`Scoring.evaluate`) feeds chapter ranks/stars and the arena. Tokens buy `GameState.UPGRADES` / `SUITS` (extra suits = classic sheet + `assets/shaders/suit_tint.gdshader`).
- `CombatCamera` (group `camera_director`) owns camera zoom/offset; Fx shake rides on top via `Fx.set_camera_base`. `PostFX` (layer 5, group `post_fx`) grades the world; the HUD is on layer 10.
- `HitboxComponent` hits each target at most once per activation. `HealthComponent.grant_invulnerability()` is used for dodges, respawns and cutscenes.
- `EnemyBase` builds its own components in code. Use `configure(params)` before `add_child`. Bosses use `stagger_resist` and the `BossBase` signals (`boss_engaged/health_updated/status_changed/defeated`).
- Chapters are data in `LevelRegistry`. `CampaignLevel` runs the objectives (reach, defeat_tag, defeat_boss, thief_cornered, collect, break_tag, rescue, escape, scripted). Checkpoints store the objective index. Retry always reloads the **current** chapter.
- Autoload names (GameState/Audio/Fx) are not available while a `-s` SceneTree script is compiling. Test and tool launchers `await process_frame` and then `load()` their job or suite scripts.
- Camera zoom is 1.25 (512×288 visible). Design level geometry for that view: jump 59 px high (~145 px wide), super jump 125 px high, web anchors within 185 px above the player.

## 5. Commands
```bash
G=/Users/tusharbhojwani/Downloads/Godot.app/Contents/MacOS/Godot
$G --path .                                                                  # play
$G --headless --fixed-fps 60 --path . -s res://tests/headless_test_runner.gd  # all tests (TEST_SUITE=campaign to filter)
$G --headless --path . -s res://tests/compile_check.gd                         # compile every script/scene
python3 tools/art/build_all.py && python3 tools/audio/build_audio.py && $G --headless --path . --import   # regenerate assets
$G --path . --resolution 1280x720 -s res://tools/capture/capture_scenes.gd -- /tmp/caps                   # screenshots (opens a window)
$G --path . --resolution 960x540 --fixed-fps 30 --write-movie /tmp/demo/frame.png -s res://tools/capture/record_demo.gd
python3 tools/capture/make_gif.py /tmp/demo docs/media/gameplay.gif
```
After regenerating PNG/WAV assets, always run `--import`. A plain `--path` run does not reimport.

## 6. Web export
Preset "Web": `thread_support=false` (no COOP/COEP needed), relative paths, excludes `tools/ tests/ docs/ *.md`. Export templates must match 4.7.2 exactly (`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`).
```bash
$G --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server 8000 --directory build/web
```

## 7. Android export
Preset "Android": arm64-v8a, landscape, `com.nightslinger.prototype`. Still needed: OpenJDK 17, Android SDK (platforms;android-34, build-tools;34.0.0), and the SDK path plus debug keystore in Editor Settings. Never commit keystores.

## 8. Known limitations
- Art and music are procedural originals from `tools/`, not hand-made. Characters are pre-rendered 3D-look sprites (not real 3D models). Backgrounds are still 2D painted layers. Swap atlas PNGs while keeping the frame grid.
- Ceiling crawl needs flat ceilings. Its art is posed on all fours and flipped vertically in `vol_build.render_frame` (`Pose.flip_v`). Mobile touch and the APK are untested on a device.
