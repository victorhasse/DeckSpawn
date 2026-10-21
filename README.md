# DeckSpawn

**Bring physical cards to life through augmented reality.**

A personal and academic **iOS card-battle game** built with **Swift, SwiftUI, ARKit, and RealityKit**. DeckSpawn recognizes physical cards, summons their corresponding animated 3D characters into an augmented-reality scene, and supports single-player battles and local multiplayer between two iPhones.

[**English**](README.md) · [**Português (Brasil)**](README.pt-BR.md)

> **Project status:** In active development  
> **Repository type:** Public source-code showcase for learning and portfolio purposes  
> **Important:** This repository does **not** include the game's 3D character models, animation files, reference card images, or audio files. See [Assets and limitations](#assets-and-limitations) and [Licensing](#licensing).

---

## Contents

- [About the game](#about-the-game)
- [Gameplay showcase](#gameplay-showcase)
- [Features](#features)
- [How the game works](#how-the-game-works)
- [Technology stack](#technology-stack)
- [Project architecture](#project-architecture)
- [Getting started](#getting-started)
- [Assets and limitations](#assets-and-limitations)
- [Development status and plans](#development-status-and-plans)
- [Public repository and development history](#public-repository-and-development-history)
- [Licensing](#licensing)
- [About the project](#about-the-project)

## About the game

**DeckSpawn** combines physical trading cards with interactive 3D characters. By pointing an iPhone's camera at a supported printed card, the player triggers image recognition and can summon a corresponding character into an augmented-reality scene.

The experience extends beyond scanning: players can select characters and participate in battles, either against a game-controlled opponent or another player on a nearby iPhone. The project explores how augmented reality, game-state management, animation, and device-to-device communication can work together in one native iOS app.

## Gameplay showcase

*Real gameplay screenshots and video will be added here.*

### Screenshots

| Main menu | Card scanning | AR battle |
|:---:|:---:|:---:|
| *Coming soon* | *Coming soon* | *Coming soon* |

<!-- SCREENSHOT GUIDE — replace the placeholder row when ready.
Create docs/media/ and use your own screenshots that you are authorized to publish.

| Main menu | Card scanning | AR battle |
|:---:|:---:|:---:|
| ![DeckSpawn main menu](docs/media/main-menu.png) | ![Scanning a physical card](docs/media/card-scanning.png) | ![Augmented reality battle](docs/media/ar-battle.png) |

Optional: add a second table for multiplayer connection, character selection,
and the victory/defeat screen. Keep image filenames the same in both READMEs.
-->

### Gameplay video

*Video demonstration coming soon.*

<!-- VIDEO GUIDE — replace the line above when ready.
For a hosted video:
[Watch the DeckSpawn gameplay demo](YOUR_VIDEO_URL)

For a clickable video thumbnail:
[![Watch DeckSpawn gameplay](docs/media/gameplay-thumbnail.png)](YOUR_VIDEO_URL)

Do not publish footage or character artwork unless you have the necessary rights.
-->

## Features

| Feature | Description |
|---|---|
| **Physical card recognition** | Detects supported printed cards through the iPhone camera with ARKit image tracking. |
| **AR character summoning** | Presents a corresponding animated 3D character in the camera scene. |
| **Character animations** | Loads character-specific animations for gameplay actions and outcomes. |
| **Single-player battles** | Lets a player choose a character and face a game-controlled opponent. |
| **Local multiplayer** | Connects two nearby iPhones for multiplayer battles. |
| **Battle system** | Coordinates battle moves, rules, state transitions, and results. |
| **Sound and haptic feedback** | Provides audiovisual/tactile responses, including victory or defeat audio according to the result on each device. |
| **Bilingual interface** | Supports Brazilian Portuguese and English localization. |

> These systems are part of an evolving project. Their behavior may change as gameplay and stability are refined.

## How the game works

### Single-player

1. Start a single-player match.
2. Scan a supported physical card with the iPhone camera.
3. View the matching character summoned in AR.
4. Choose **Ready** to confirm or **Change Character** to scan a different card.
5. The game selects an opponent and starts the battle after a countdown.
6. Complete the match and receive feedback based on the result.

### Local multiplayer

1. Both players launch DeckSpawn on separate compatible iPhones.
2. The devices establish a nearby multiplayer connection.
3. Players select their characters and proceed through the match flow.
4. The game coordinates battle events and results between the devices.
5. Each iPhone presents the outcome from **its own player's perspective**—for example, the winner hears the victory sound while the other player hears the defeat sound.

## Technology stack

| Technology | Purpose |
|---|---|
| **Swift** | App logic, game rules, and state management |
| **SwiftUI** | Screens, menus, and UI updates |
| **ARKit** | Image recognition and AR tracking |
| **RealityKit** | AR content and 3D entity presentation |
| **MultipeerConnectivity** | Nearby-device communication for multiplayer |
| **Xcode** | iOS development, configuration, and testing |
| **Blender / USDZ** | 3D preparation and animation asset workflow (assets are not distributed here) |

## Project architecture

The public repository retains the original source-code organization. Some resource directories are present only in the private development copy.

```text
DeckSpawn/                           # Public repository
├── App/
│   └── MyApp.swift
├── Features/
│   ├── Main/                        # Main menu and settings
│   │   └── Views/
│   ├── MultiPlayer/                 # Multiplayer models, service, and views
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Views/
│   ├── Shared/                      # AR, battle logic, haptics, and card models
│   │   ├── AR/
│   │   ├── Battle/
│   │   ├── Haptics/
│   │   ├── Models/
│   │   └── Views/
│   └── SinglePlayer/                # Single-player flow and views
│       ├── Models/
│       └── Views/
├── Services/
│   └── Audio/                       # SoundManager.swift (source code only)
├── Resources/
│   └── Assets.xcassets/             # App icon, DeckSpawn logo, accent color
├── CardArenaAR.xcodeproj/           # Existing Xcode project name
├── CardArenaAR-Info.plist
├── DeckSpawnL10n.swift
├── Localizable.xcstrings
├── .gitignore
├── README.md
├── README.pt-BR.md
└── LICENSE                           # MIT license (added separately)
```

**Key source files:**

| File | Responsibility |
|---|---|
| `Features/Shared/AR/ARViewContainer.swift` | AR session, card-image detection, and integration with gameplay |
| `Features/Shared/AR/GameARState.swift` | Shared state for the AR experience |
| `Features/Shared/Battle/` | Battle engine, moves, rules, and state |
| `Features/Shared/Models/CardDatabase.swift` | Card definitions and associated character/model identifiers |
| `Features/Shared/Models/CharacterAnimationSet.swift` | Animation naming and lookup configuration |
| `Features/MultiPlayer/Services/MultiplayerService.swift` | Multiplayer communication and coordination |
| `Features/SinglePlayer/` | Single-player game flow and UI |
| `Services/Audio/SoundManager.swift` | Audio playback and game-result feedback |
| `Localizable.xcstrings` | Interface translations |

> **Why is the Xcode project called `CardArenaAR`?** That was the project's original working name. **DeckSpawn** is the game's current public name; the internal Xcode project and some source identifiers still use the original name.

## Getting started

### Requirements

- A Mac with a suitable version of **Xcode** installed.
- A compatible **physical iPhone** for camera-based AR functionality.
- Two compatible iPhones to explore the complete local multiplayer flow.
- Your own Apple development signing configuration, if required.
- Properly licensed replacement assets if you wish to run the asset-dependent gameplay.

### Open the source project

```bash
git clone https://github.com/victorhasse/DeckSpawn.git
cd DeckSpawn
open CardArenaAR.xcodeproj
```

Open the project in Xcode, review its signing settings and required device permissions, then inspect the source. To attempt a playable build, provide suitable assets and update any resource references or build settings that require them.

**A clone of this repository is not guaranteed to build or run the full game as-is.** Please read the next section before trying to run it.

## Assets and limitations

The public repository is intended to showcase the **source code**, not distribute a complete playable game package.

The following resources are intentionally **not committed**:

| Excluded from the public repository | Original development location |
|---|---|
| 3D character models, textures, and animation assets | `Resources/Models3D/` |
| Gameplay sound effects and audio files | `Resources/Audio/` |
| Physical-card reference images used by ARKit | `Resources/Assets.xcassets/AR Resources.arresourcegroup/` |

The **DeckSpawn app icon, logo, and accent-color resources** are retained in `Resources/Assets.xcassets/` for project identification; their availability does **not** place them under the code's MIT License.

The Swift source may contain references to absent asset filenames (for example, `.usdz` or `.wav`) and to ARKit's `AR Resources` reference-image group. Such references identify resources expected by the app; **the resource contents are not included**. Without replacements, scanning, character display, audio, and other gameplay functions may be unavailable. Depending on the Xcode configuration, missing files may also cause build errors.

If you reuse the code, supply **your own assets or assets you are authorized to use**, update the matching identifiers and references, and verify the configuration on your devices.

## Development status and plans

DeckSpawn is an ongoing **personal and academic project**, not a completed commercial release. Work so far covers the foundation of AR card recognition, animated character presentation, single-player and local multiplayer battle flows, battle logic, localization, and audio/haptic feedback.

Areas planned or being explored include:

- Fixing edge cases and improving the scanning/gameplay experience.
- Refining animations, game feedback, and presentation.
- Replacing third-party character content with **original characters and artwork**.
- Improving documentation and reproducibility of the public codebase.

This list reflects current intentions and is not a fixed release schedule.

## Public repository and development history

DeckSpawn was originally developed in a **private repository** under the working project name `CardArenaAR`. This public repository begins with a **curated source-code snapshot**: the original private Git history and non-distributable game assets are not included.

A large initial commit therefore represents the **publication of an existing project**, not the entirety of its development in one day. Future public updates may be added as the project evolves.

## Licensing

### Source code — MIT

The project's **original source code** is licensed under the **[MIT License](LICENSE)**. Under that license, the covered code may be used, modified, and redistributed—including commercially—provided the license terms and copyright notice are retained.

### Assets, branding, and third-party intellectual property

**The MIT License applies to the original source code only. It does not grant rights to the game's assets, character identities, audiovisual materials, or branding.** In particular, it does not automatically cover:

- Third-party 3D models, rigs, animations, textures, or artwork.
- Recognizable characters, character names, logos, or trademarks owned by third parties.
- Physical-card artwork and AR reference images.
- Sound effects, music, video footage, or other media.
- The DeckSpawn name, logo, app icon, or other original branding, unless separately licensed.

Third-party materials remain subject to their owners' rights and applicable licenses. Their appearance in project descriptions, source references, screenshots, or demonstrations **does not grant permission to copy, redistribute, or commercially use them**. The project is not affiliated with, sponsored by, or endorsed by any owners of third-party characters or brands depicted in development materials.


## About the project

DeckSpawn is both a personal experiment and an academic project. Its purpose is to explore practical iOS engineering through a game that combines **augmented reality, physical input, 3D animation, UI design, and local multiplayer networking**.

<!-- PORTFOLIO LINK — replace this line once your website page is available.
**Portfolio:** [View the DeckSpawn case study](YOUR_PORTFOLIO_URL)
-->

*Portfolio case study link coming soon.*
