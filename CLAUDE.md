# CLAUDE.md — Web-Slinger: Night Patrol (Phase 1 Prototype)

## 1. Environment & Engine Configuration
- **Target Engine**: Godot 4.3+ Stable (`config_version=5`, `GL Compatibility` renderer for Desktop, Mobile, and Web).
- **Host Machine Audit (2026-10-28)**:
  - **Godot Editor Binary**: Not currently installed in `/Applications`, `/opt/homebrew/bin`, or `/usr/local/bin`.
  - **Export Templates**: Not present in `~/Library/Application Support/Godot/export_templates/`.
  - **Android Build Tools**: `adb` and Android SDK are not installed; `/usr/bin/java` is a macOS stub without an active JDK runtime.
  - **Python 3**: `/usr/bin/python3` and `/opt/homebrew/bin/python3` (3.14.7) are installed and used for procedural asset generation, structural validation, and local HTTP serving.

## 2. Folder Structure
```text
.
├── .gitignore
├── CLAUDE.md
├── README.md
├── export_presets.cfg
├── project.godot
├── assets/
│   ├── audio/
│   │   ├── boss_warn.wav
│   │   ├── defeat.wav
│   │   ├── hit.wav
│   │   ├── hurt.wav
│   │   ├── jump.wav
│   │   ├── kick.wav
│   │   ├── punch.wav
│   │   ├── super_jump.wav
│   │   └── web_shoot.wav
│   └── sprites/
│       ├── boss_enforcer.png
│       ├── enemy_thug.png
│       ├── hero_dark_suit.png
│       ├── hero_red_blue.png
│       ├── icon.png
│       ├── throwable_crate.png
│       ├── web_anchor.png
│       └── web_projectile.png
├── scenes/
│   ├── enemies/
│   │   ├── normal_enemy.tscn
│   │   └── prototype_boss.tscn
│   ├── levels/
│   │   └── prototype_level.tscn
│   ├── objects/
│   │   ├── throwable_object.tscn
│   │   └── web_projectile.tscn
│   ├── player/
│   │   └── player.tscn
│   └── ui/
│       └── hud_and_touch.tscn
├── scripts/
│   ├── combat/
│   │   ├── health_component.gd
│   │   ├── hitbox_component.gd
│   │   ├── hurtbox_component.gd
│   │   ├── throwable_object.gd
│   │   └── web_projectile.gd
│   ├── enemies/
│   │   ├── normal_enemy.gd
│   │   └── prototype_boss.gd
│   ├── levels/
│   │   └── prototype_level.gd
│   ├── player/
│   │   └── player_controller.gd
│   └── ui/
│       └── hud_and_touch.gd
└── tests/
    └── headless_test_runner.gd
```

## 3. Input Map (`project.godot`)
| Action Name | Desktop Keys | Touch Overlay Button | Gameplay Behaviour |
| :--- | :--- | :--- | :--- |
| `move_left` | `A` / `Left Arrow` | `LEFT` | Run left, air steer left, ceiling crawl left, pendulum swing pump |
| `move_right` | `D` / `Right Arrow` | `RIGHT` | Run right, air steer right, ceiling crawl right, pendulum swing pump |
| `climb_up` | `W` / `Up Arrow` | `CLIMB` | Attach/climb walls, attach ceiling, or combine with `Space` for Super Jump |
| `climb_down` | `S` / `Down Arrow` | `DOWN` | Climb down wall or explicitly detach from ceiling crawl |
| `jump` | `Space` | `JUMP` | Variable-height jump, wall jump, release web swing, or `W + Space` Super Jump |
| `attack_punch` | `J` | `PUNCH` | Jab -> Cross -> Spider Finisher 3-hit chained combo |
| `attack_kick` | `H` | `KICK` | Roundhouse kick or combo finisher |
| `web_action` | `K` | `WEB` | Web shot projectile (stuns enemies) or overhead Web Swing tether when airborne / holding Up |
| `special_action` | `L` | `SPEC/THROW` | Yank & throw nearby crate (`ThrowableObject`) or execute Web Impact Slam |
| `suit_toggle` | `C` | `SUIT (C)` | Switch between Classic Red/Blue Suit and Dark Suit palette (+8% run speed, +4 melee damage) |
| `pause_game` | `Escape` | `PAUSE` | Pause/resume gameplay or open Retry overlay |

## 4. Movement & Combat Architecture
- **Player State Machine (`PlayerController`)**: Uses an explicit `State` enum (`IDLE`, `RUNNING`, `JUMPING`, `FALLING`, `WALL_CLIMBING`, `CEILING_CRAWLING`, `WEB_SWINGING`, `ATTACKING`, `HURT`, `DEFEATED`) rather than conflicting boolean flags.
- **Wall & Ceiling Crawling**: Wall attachment activates when touching a wall and holding `climb_up` or pressing into the wall. Reaching the top of a ledge while climbing vaults the player onto the rooftop (`CORNER_VAULT_BOOST`). Jumping into an overhead ceiling while holding `climb_up` transitions into `CEILING_CRAWLING`, which applies upward adhesion force (`velocity.y = -45.0`) until the player detaches with `climb_down` or `jump` or reaches the end of the ceiling.
- **Web Traversal**: Pressing `web_action` (`K`) while airborne (or holding `climb_up`) searches the `"web_anchors"` group for overhead anchors within `185 px`. When attached, `Line2D` renders the live web line and constrains radial distance while preserving tangential momentum on release (`WEB_RELEASE_BOOST`).
- **Combat & Single-Hit Protection**:
  - `HitboxComponent` maintains a per-activation `_hit_registry` dictionary keyed by target instance ID so an attack swing damages each enemy at most once.
  - `HealthComponent` enforces `invulnerability_duration` so repeated overlaps cannot drain health every frame.
- **Level Reset (`PrototypeLevel.restart_level()`)**: Frees all active nodes in the `"projectiles"` group, resets all `"throwables"` and `"enemies"` to their initial positions and health, resets `PrototypeBoss` to `DORMANT`, and restores `Player` without reloading the entire campaign or duplicating nodes.

## 5. Build, Run & Test Commands
Once Godot 4.3+ (`godot`) is installed in `PATH` or `/Applications/Godot.app`:

```bash
# Open project in Godot Editor
/Applications/Godot.app/Contents/MacOS/Godot --editor --path /Users/tusharbhojwani/Desktop/Projects05

# Run the playable prototype directly
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/tusharbhojwani/Desktop/Projects05

# Run the automated headless gameplay test suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/tusharbhojwani/Desktop/Projects05 -s res://tests/headless_test_runner.gd
```

## 6. Web Export Steps (GitHub Pages Compatible)
`export_presets.cfg` is pre-configured with preset `"Web"` (`variant/thread_support=false` so it works on standard GitHub Pages without requiring custom `Cross-Origin-Embedder-Policy` / `SharedArrayBuffer` headers).
1. Install Godot 4.3+ Export Templates (`Editor -> Manage Export Templates -> Download and Install`).
2. Export the Web build:
   ```bash
   mkdir -p build/web
   /Applications/Godot.app/Contents/MacOS/Godot --headless --export-release "Web" build/web/index.html
   ```
3. Serve and test locally in a browser:
   ```bash
   python3 -m http.server 8000 --directory build/web
   ```

## 7. Android Export Steps
`export_presets.cfg` includes preset `"Android"` (`arm64-v8a`, package `com.nightslinger.prototype`, landscape orientation).
1. Install OpenJDK 17 (`brew install --cask temurin@17`) and Android SDK Command-line Tools (`platforms;android-34`, `build-tools;34.0.0`).
2. Configure the Android SDK path and debug keystore in Godot Editor Settings (`Export -> Android`).
3. Build and install the debug APK:
   ```bash
   mkdir -p build/android
   /Applications/Godot.app/Contents/MacOS/Godot --headless --export-debug "Android" build/android/web_slinger_prototype_debug.apk
   adb install -r build/android/web_slinger_prototype_debug.apk
   ```

## 8. Known Limitations & Unresolved Environment Blockers
- **Unverified Runtime Binary Execution**: Because the Godot 4 binary, export templates, JDK, and Android SDK are not currently installed on this Mac, headless Godot binary execution, live browser export (`build/web/index.html`), and Android APK compilation (`build/android/web_slinger_prototype_debug.apk`) could not be executed in this session and remain **unverified on device** until Godot 4 is installed.
- **Ceiling Crawl Geometry Constraint**: Ceiling crawling requires flat horizontal ceiling colliders (`is_on_ceiling()`). Sloped ceiling tiles are not yet supported in Phase 1.
