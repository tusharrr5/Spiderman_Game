# Web-Slinger: Night Patrol (Phase 1 Prototype)

A classic 2D side-scrolling superhero action-platformer prototype built in **Godot 4 (GDScript)** using the **Compatibility** renderer for desktop, web (GitHub Pages), and Android. Inspired by the classic Java mobile side-scroller *Spider-Man 3* (2007), featuring original procedural pixel-art sprites, synthesized retro sound effects, acrobatic traversal, web swinging, chained melee combos, throwable street crates, and a multi-phase prototype boss encounter.

## Playable Prototype Features (Phase 1)
- **Explicit 10-State Player Controller (`PlayerController`)**:
  - `IDLE`, `RUNNING`, `JUMPING`, `FALLING`, `WALL_CLIMBING`, `CEILING_CRAWLING`, `WEB_SWINGING`, `ATTACKING`, `HURT`, and `DEFEATED`.
- **Acrobatic Movement & Web Traversal**:
  - Responsive horizontal acceleration/deceleration and variable jump height.
  - **Super Jump (`W + Space`)**: Cooldown-based vertical burst with particle and audio feedback.
  - **Wall Crawling & Corner Vault**: Hold `W` / `Up Arrow` (or press into a wall) to cling and climb vertically, automatically vaulting over rooftop ledges at the top.
  - **Ceiling Crawling**: Jump into the underside of an overpass while holding `W` / `Up Arrow` to crawl horizontally across ceilings; press `S` / `Down Arrow` or `Space` to detach cleanly.
  - **Web Swinging (`K` in mid-air or with `W`)**: Attaches a visible `Line2D` web tether to overhead anchor points with pendulum swing physics and momentum preservation on release.
- **Web Combat & Special Moves**:
  - **3-Hit Chained Combo (`J -> J -> J/H`)**: Jab -> Cross -> Acrobatic Finisher with per-swing hitbox tracking (`HitboxComponent`).
  - **Roundhouse Kick (`H`)**: High-knockback standalone kick.
  - **Web Shot (`K`)**: Fires a `WebProjectile` that damages and web-snares enemies (`WEBBED!` stun state).
  - **Object Throw / Web Impact Slam (`L`)**: Yanks and hurls nearby street crates (`ThrowableObject`) on a parabolic arc, or triggers a cooldown-based Web Impact Slam when no crate is in range.
  - **Suit Palette Swap (`C`)**: Toggle at any time between the Classic Red-and-Blue Suit and the Dark Suit palette.
- **Enemies & Prototype Boss**:
  - **Street Thugs (`NormalEnemy`)**: Patrol rooftops, detect and approach the player, display a `!` telegraph before swinging, react to knockback and web-snares, and defeat at 0 HP.
  - **Armored Enforcer (`PrototypeBoss`)**: Features a dedicated HUD health bar, two telegraphed attacks (**Armored Dash Charge** and **Jumping Shockwave Slam**), and an explicit **Vulnerable Recovery Window** (`VULNERABLE!`) where counterattacks and thrown crates deal bonus damage.
- **HUD, Multi-Touch Controls & Clean Level Reset**:
  - Responsive 640x360 landscape viewport (`canvas_items` + `expand`) with nearest-neighbor pixel filtering.
  - Multi-touch on-screen controls (`LEFT`, `RIGHT`, `CLIMB`, `DOWN`, `JUMP`, `PUNCH`, `KICK`, `WEB`, `SPEC/THROW`, `SUIT`, `PAUSE`) mapped to the exact same Input Map actions as the keyboard.
  - Single-click **Retry Level** resets player health/position, enemies, boss, throwable crates, and active projectiles without duplicating nodes.

## Controls

| Action | Desktop Keyboard | Mobile / Touch Overlay |
| :--- | :--- | :--- |
| **Move Left / Right** | `A` / `D` or `Left` / `Right Arrow` | `LEFT` / `RIGHT` |
| **Jump (Variable Height)** | `Space` | `JUMP` |
| **Super Jump** | `W + Space` (or `Up + Space`) | Hold `CLIMB` + Tap `JUMP` |
| **Wall Climb / Ceiling Crawl** | `W` / `S` or `Up` / `Down Arrow` | `CLIMB` / `DOWN` |
| **Punch / 3-Hit Combo** | `J` (tap repeatedly on timing) | `PUNCH` |
| **Kick** | `H` | `KICK` |
| **Web Shot / Web Swing** | `K` (in air near anchor to swing) | `WEB` |
| **Throw Object / Special Move** | `L` | `SPEC/THROW` |
| **Switch Suit Palette** | `C` | `SUIT (C)` |
| **Pause / Resume** | `Escape` | `PAUSE` |

## Running the Project
1. Install **Godot 4.3+ Stable** (Standard GDScript edition).
2. Open `/Users/tusharbhojwani/Desktop/Projects05/project.godot` in Godot Editor and press **F5** (Run Project), or run from terminal:
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --path /Users/tusharbhojwani/Desktop/Projects05
   ```
3. Run the automated headless test runner:
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/tusharbhojwani/Desktop/Projects05 -s res://tests/headless_test_runner.gd
   ```
