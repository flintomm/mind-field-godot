# Mind-Field — Godot 4.x MVP

A mental wellness park where your thoughts become creatures. Submit snippets of your thoughts, emotions, and memories to four banks — and watch a living park evolve around them.

## Setup

### Prerequisites
- [Godot 4.2+](https://godotengine.org/download/) (Standard or .NET — this project uses GDScript only)

### Opening the Project
1. Launch Godot
2. Click **Import** → navigate to this folder → select `project.godot`
3. Click **Import & Edit**

### Running
- Press **F5** (or the Play button) — runs `scenes/main.tscn`
- The game starts immediately with a snippet input panel

## Architecture

### Autoloaded Singletons
- **EventBus** — Global signal hub for decoupled communication
- **GameManager** — Orchestrator; initializes all subsystems, auto-saves every 5 minutes

### Core Systems (under `scripts/`)
| System | File | Purpose |
|--------|------|---------|
| State | `state_manager.gd` | Observable key-value store, JSON save/load |
| Time | `time_manager.gd` | Day/night cycle, ambient lighting, snippet timing |
| Banks | `banks/bank_registry.gd` | 4 emotional banks (Ivorai, Glyffins, Zoraqians, Yagari) |
| Day Unit | `day_unit/day_unit.gd` | Daily avatar that morphs with engagement |
| Habits | `habits/habit_system.gd` | Trackable habits with decay, modules, rewards |
| Districts | `districts/district_manager.gd` | 4 themed zones with traffic simulation |
| Simulation | `simulation/simulation_manager.gd` | Tick-based loop driving decay & conversions |
| Data | `data/local_data_store.gd` | JSON file persistence to `user://` |

### The Four Banks
| Bank | Race | Theme | Colors |
|------|------|-------|--------|
| Ivorai | Elephant-inspired | Good Memories | Ivory / Bronze |
| Glyffins | Geometric | Hopes & Dreams | Silver / Brass |
| Zoraqians | Alien/Brood | Bad Memories | Deep Purple / Toxic Green |
| Yagari | Dark Sentinels | Fears | Near-Black / Smoky Blue |

### Day Unit Morph Stages
| Stage | Threshold | Visual |
|-------|-----------|--------|
| Base | 0 min | Spawn form |
| Shoes | 30 min | Boots appear |
| Gloves | 60 min | Gauntlets added |
| Chest | 2 hr | Chestplate overlay |
| Helm | 4 hr | Crown/helmet |
| Retired | End of day | Becomes Attendee |

### Habit Foundations
| Type | Theme | Color |
|------|-------|-------|
| Station | Exercise | Green |
| Workshop | Study | Blue |
| Sanctuary | Rest | Purple |
| Forge | Discipline | Orange |
| Market | Chores | Gold |

## Gameplay Loop
1. **Submit snippets** — Type thoughts, select a bank, adjust mood slider
2. **Day Unit spawns** — Race determined by dominant bank
3. **Morph progression** — More engagement → more armor pieces
4. **Fusion** — Secondary bank adds visual accents (1-3)
5. **Spam detection** — Rapid inputs (<30s) yield only cosmetic changes
6. **Habits** — Create, complete daily, watch decay/growth
7. **End of day** — Day Unit retires as permanent Attendee
8. **Auto-save** — Every 5 minutes + on exit

## Exporting

### Web (HTML5) — for itch.io
1. Install the **Web** export template: Editor → Manage Export Templates → Download
2. Project → Export → Select "Web" preset
3. Export Project → choose output folder
4. Upload the entire folder to itch.io (set to HTML project)

### iOS
1. Install the **iOS** export template
2. Project → Export → Select "iOS" preset
3. Fill in your Team ID and provisioning profile
4. Export Project → generates Xcode project
5. Open in Xcode → Build & Run

### macOS
1. Install the **macOS** export template
2. Project → Export → Select "macOS" preset
3. Export Project → generates .dmg or .app

### Windows
1. Install the **Windows Desktop** export template
2. Project → Export → Select "Windows" preset
3. Export Project → generates .exe

## Placeholder Assets
All SVG sprites in `assets/sprites/` are placeholder art with distinctive silhouettes:
- **Races**: 4 unique body shapes (wide elephant, angular hex, asymmetric blob, tall cloak)
- **Habits**: 5 building types (gym, library, dome, anvil, market stall)
- **Districts**: 4 terrain backgrounds
- **UI**: Bank selector icons, thought bubbles
- **Morph**: Shoes, gloves, chest, helm overlays

Replace with production art while maintaining the same color coding and silhouette distinctiveness.

## File Structure
```
mind-field-godot/
├── project.godot          # Godot project file
├── icon.svg               # App icon
├── assets/sprites/        # All SVG placeholder sprites
├── scenes/                # .tscn scene files
│   ├── main.tscn          # Root scene (park + UI)
│   ├── ui/                # UI scenes
│   ├── entities/          # Day unit, attendee, thought bubble
│   ├── districts/         # District scenes
│   └── habits/            # Habit visual scenes
├── scripts/               # All GDScript files
│   ├── game_manager.gd    # Autoloaded singleton
│   ├── event_bus.gd       # Autoloaded signal hub
│   ├── banks/             # Bank system
│   ├── day_unit/          # Day unit logic + controller
│   ├── habits/            # Habit system
│   ├── districts/         # District management
│   ├── simulation/        # Tick-based simulation
│   ├── ui/                # UI controllers
│   └── data/              # Save/load + resource definitions
├── resources/             # Theme, configurations
└── export_presets.cfg     # Export configurations
```
