# CLAUDE.md — Web-Slinger: Night Patrol

## 1. Environment
- **Engine**: Godot **4.7.2 stable** (`config_version=5`, GL Compatibility renderer on desktop, mobile and web).
- **Godot binary on this Mac**: `/Users/tusharbhojwani/Downloads/Godot.app/Contents/MacOS/Godot` (the editor may run from an AppTranslocation copy of it; do not hardcode that path).
- **Python**: `python3` from `/Library/Frameworks/Python.framework/Versions/3.14` has Pillow 12 and numpy (used by `tools/`). `/usr/bin/python3` and Homebrew python3 do **not** have Pillow.
- **Export templates**: see section 6. **Android**: no JDK runtime, Android SDK or `adb` installed (section 7).

## 2. Layout
```text
scripts/core/      game_state.gd (autoload GameState), audio_manager.gd (Audio), fx.gd (Fx), sprite_animator.gd
scripts/player/    player_controller.gd  (PlayerController state machine)
scripts/combat/    health/hitbox/hurtbox components, web_projectile, enemy_projectile, throwable_object
scripts/enemies/   enemy_base -> normal_enemy (thug), gunner_enemy, drone_enemy; boss_base -> thief_boss, goblin_boss; prototype_boss (Brick)
scripts/levels/    campaign_level.gd, level_builder.gd, prototype_level.gd, objects/ (platforms, zones, gates, breakables, follower)
scripts/data/      level_registry.gd (ALL chapter data), story_data.gd, sprite_db.gd (GENERATED - do not edit)
scripts/ui/        hud_and_touch.gd, dialogue_box.gd, input_diagnostics.gd, menus/ (title, level select, story, credits, ui_kit)
scenes/            menus/*.tscn, levels/campaign_level.tscn + prototype_level.tscn, player, enemies, objects, ui
assets/            sprites/characters (generated strips), backgrounds/<theme>, tiles, props, portraits, story, ui, audio, music
tools/art|audio|capture   asset generators, screenshot capture, README GIF recording
tests/             headless_test_runner.gd (launcher), suites/prototype_suite.gd, suites/campaign_suite.gd, compile_check.gd
docs/media/        README screenshots + gameplay.gif
```
Main scene: `res://scenes/menus/title_screen.tscn`. The original prototype level still exists and is used by `prototype_suite`.

## 3. Input
Actions: `move_left/right` (A/D, arrows), `climb_up/down` (W/S, arrows), `jump` (Space), `attack_punch` (J), `attack_kick` (H), `web_action` (K), `special_action` (L), `suit_toggle` (C), `dodge` (Shift), `pause_game` (Esc). Each key is bound by both keycode and physical keycode.
- On-screen buttons call `Input.action_press/release` **and** `PlayerController.buffer_action_tap/release` (the shared action interface). Releasing on window focus loss is handled in the HUD, because the engine does not release `action_press` state.
- `PlayerController.input_locked` freezes input during cutscenes.
- **Editor Game tab gotcha**: in 2D/3D Select or Suspend mode, Godot calls `Input.set_disable_input(true)` and `root.set_disable_input_override(true)`. No game code receives input. `Viewport.is_input_disabled()` does NOT report this. The F3 diagnostics overlay detects it (`INPUT_SINGLETON_BLOCKED`) and logs to `user://input_diag_<mode>.log`. The fix is the Game tab's gamepad "Input" toggle; do not add workarounds in game code.
- Verified with real OS keystrokes in a standalone window (2026-10-28): movement, wall climb, ceiling crawl, jump/super jump, web shot/swing and special. On-screen buttons with a real mouse, J/H/Esc, and real mobile touch have **not** been manually verified.

## 4. Gameplay architecture
- Player states: IDLE, RUNNING, JUMPING, FALLING, WALL_CLIMBING, CEILING_CRAWLING, WEB_SWINGING, ATTACKING, HURT, DEFEATED, DODGING. The collision body is 14×30 with feet at local y=+14. Sprites are 96 px frames shown at 0.5 scale.
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
- Art and music are procedural originals from `tools/`, not hand-made. Swap the PNG strips while keeping the frame layout.
- Ceiling crawl needs flat ceilings. Mobile touch and the APK are untested on a device.
