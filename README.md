<img width="1448" height="1086" alt="DeckSpawn_logo" src="https://github.com/user-attachments/assets/ba67d7e5-bd88-4e0a-a2be-1daa41688502" />


# DeckSpawn

**Bring physical cards to life through augmented reality.**

A native **iOS card-battle game** developed as a personal and academic project. Built with **Swift, SwiftUI, ARKit, RealityKit, and MultipeerConnectivity**, DeckSpawn turns physical cards into animated 3D fighters, combining augmented-reality combat, character-specific visual effects, single-player battles, and local multiplayer between two iPhones.

**Scan a card. Summon a character. Battle in AR.**

[**English**](README.md) · [**Português (Brasil)**](README.pt-BR.md)

> **Project status:** Functional prototype — single-player and local multiplayer implemented; in active development  
> **Repository type:** Public source-code showcase for learning and portfolio purposes  
> **Important:** This repository does **not** include the game's 3D character models, animation files, reference card images, or audio files. See [Assets and limitations](#assets-and-limitations) and [Licensing](#licensing).

---

## Contents

- [About the game](#about-the-game)
- [Gameplay showcase](#gameplay-showcase)
- [Features](#features)
- [Playable characters and combat effects](#playable-characters-and-combat-effects)
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

**DeckSpawn** combines physical trading cards with interactive 3D characters. Pointing an iPhone's camera at a supported printed card triggers image recognition and allows the player to summon the corresponding character into an augmented-reality scene.

The card is the starting point of a playable battle, rather than just a trigger for a 3D model. Players select their fighters, enter combat against a game-controlled opponent or a nearby player, and receive visual, audio, and haptic feedback throughout the experience.

The project explores the integration of native iOS development, AR tracking, 3D animation, battle-state management, and device-to-device networking. Both game modes are implemented, and the local multiplayer flow has been tested on physical iPhones.

## Gameplay showcase

*Real gameplay screenshots and video*

### Screenshots

| Main menu | Card scanning | AR battle |
|:---:|:---:|:---:|
| *Coming soon* | *Coming soon* | *Coming soon* |

| Character selection | Local multiplayer | Battle result |
|:---:|:---:|:---:|
| *Coming soon* | *Coming soon* | *Coming soon* |

<!-- SCREENSHOT GUIDE — replace the placeholder rows when ready.
Create docs/media/ and use your own screenshots that you are authorized to publish.

| Main menu | Card scanning | AR battle |
|:---:|:---:|:---:|
| ![DeckSpawn main menu](docs/media/main-menu.png) | ![Scanning a physical card](docs/media/card-scanning.png) | ![Augmented reality battle](docs/media/ar-battle.png) |

| Character selection | Local multiplayer | Battle result |
|:---:|:---:|:---:|
| ![Character selection](docs/media/character-selection.png) | ![Local multiplayer connection](docs/media/local-multiplayer.png) | ![Battle result](docs/media/battle-result.png) |

Keep image filenames the same in both READMEs.
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
| **Physical card recognition** | Detects supported printed cards through the iPhone camera using ARKit image tracking. |
| **AR character summoning** | Loads the corresponding animated 3D fighter into the real-world camera scene. |
| **Character selection** | Lets the player confirm a summoned character or scan a different card before battle. |
| **Single-player (PvE)** | Battles against a randomly selected, game-controlled opponent. |
| **Local multiplayer (PvP)** | Connects two nearby iPhones through Network.framework + Bonjour for player-versus-player battles. |
| **Battle system** | Coordinates combat moves, rules, the pre-battle countdown, state transitions, and match results. |
| **Multiplayer synchronization** | Exchanges gameplay information between devices and coordinates match progression and results from each player's perspective. |
| **3D character animations** | Character-specific animation sets for idle poses, combat actions, and battle reactions/outcomes. |
| **Combat visual effects (VFX)** | Custom attack effects, including motion trails and character-specific colors, complement the 3D combat animations. |
| **Sound effects (SFX)** | Audio feedback for card scanning and character summoning, with distinct victory and defeat sounds for each player's result. |
| **Haptic feedback** | Tactile responses complement gameplay interactions. |
| **Localized interface** | Menus and game interface available in English and Brazilian Portuguese. |

## Playable characters and combat effects

The development build currently includes four playable characters, each associated with a physical card and its own 3D animation set.

| Character | Picture |
|---|---|
| Spider-Man | <img width="575" height="460" alt="spiderman_cardgame" src="https://github.com/user-attachments/assets/776227f3-d448-49f3-a283-a80008de0ad3" /> |
| Stormtrooper | <img width="575" height="460" alt="stormtrooper_cardgame" src="https://github.com/user-attachments/assets/6403981f-6d13-409c-809a-ae3a0206d666" /> |
| Goku | <img width="575" height="460" alt="goku_cardgame" src="https://github.com/user-attachments/assets/5847e81b-6fac-4701-bc96-01e1ab8e9654" /> |
| Mrs. Incredible (Elastigirl) | <img width="575" height="460" alt="mrsincredible_cardgame" src="https://github.com/user-attachments/assets/73b227ce-9143-478a-9512-d72edfd671b0" /> |

Effects were developed to highlight the movement of each attack, rather than just displaying generic effects around the characters. The Stormtrooper's attack trails, Mrs. Incredible's punch and kick effects, Goku's signature Kamehameha, and Spider-Man's web effects are among the recent additions to the combat presentation.

Character preparation involves importing and rigging 3D models, preparing animations, and exporting animation assets in USDZ format for RealityKit. The game associates each supported card with the corresponding character and animation identifiers.

> These recognizable third-party characters are used as development and learning references. Their models, textures, animation files, and card artwork are not distributed in this public repository. See [Licensing](#licensing).

## How the game works

### Single-player

1. Choose the single-player mode in the main menu.
2. Scan a supported physical card with the iPhone camera.
3. View the corresponding animated character summoned in AR.
4. Choose **Ready** to confirm or **Change Character** to scan a different card.
5. The game randomly selects an opponent and starts a pre-battle countdown.
6. Play the match using the battle system, with character animations and combat effects.
7. Receive feedback corresponding to the battle result.

### Local multiplayer

1. Launch DeckSpawn on two separate compatible iPhones.
2. Establish a nearby connection in the multiplayer mode using MultipeerConnectivity.
3. Each player selects a fighter by scanning a supported physical card.
4. Both players advance through the match flow and enter combat.
5. The game exchanges gameplay information between the devices to coordinate battle progression and results.
6. Each iPhone presents the result from **its own player's perspective**: the winner hears the victory sound, while the losing player hears the defeat sound.

The local multiplayer mode is functional and does not rely on a dedicated online game server or Game Center. Both devices must have a playable build installed. Internet-based multiplayer and remote matchmaking are not implemented.

## Technology stack

| Technology | Purpose |
|---|---|
| **Swift** | App logic, game rules, and state management |
| **SwiftUI** | Screens, menus, and UI updates |
| **ARKit** | Image recognition and AR tracking |
| **RealityKit** | 3D entity presentation, animation playback, and AR combat effects |
| **Network.framework** | Nearby-device communication for multiplayer |
| **Xcode** | iOS development, configuration, and testing |
| **Blender / Mixamo** | 3D model preparation, rigging, and character animation workflow |
| **USDZ** | 3D model and animation asset format used in RealityKit (assets not distributed here) |
| **String Catalog (`.xcstrings`)** | English and Brazilian Portuguese localization |

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
| `Features/Shared/AR/ARViewContainer.swift` | AR session, card-image detection, character presentation, animation playback, and combat effects |
| `Features/Shared/AR/GameARState.swift` | Shared state for the AR experience |
| `Features/Shared/Battle/` | Battle engine, moves, rules, and state |
| `Features/Shared/Models/CardDatabase.swift` | Card definitions and associated character/model identifiers |
| `Features/Shared/Models/CharacterAnimationSet.swift` | Animation naming and lookup configuration |
| `Features/MultiPlayer/Services/MultiplayerService.swift` | Nearby-device communication and multiplayer coordination |
| `Features/SinglePlayer/` | Single-player game flow and UI |
| `Services/Audio/SoundManager.swift` | Scanning, summoning, and game-result audio feedback |
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

DeckSpawn is a functional prototype developed for personal, academic, and portfolio purposes, not a commercial release. The current focus is refining the implemented game modes and presentation rather than expanding into online services.

### Implemented features

- [x] Physical card recognition and animated character summoning in AR.
- [x] Single-player battles against game-controlled opponents.
- [x] Functional local multiplayer between two physical iPhones.
- [x] Four playable characters with dedicated animation sets.
- [x] Character-specific combat VFX, including Stormtrooper and Mrs. Incredible attack effects.
- [x] Scanning and summoning audio, haptics, and victory/defeat sounds.
- [x] English and Brazilian Portuguese localization.
- [x] Public source-code repository separated from non-distributed assets.

### Future improvements

- [ ] Improve scanning reliability, performance, and gameplay stability.
- [ ] Refine combat animations, visual effects, and presentation.
- [ ] Expand documentation and facilitate testing with authorized replacement assets.
- [ ] Add gameplay screenshots and video demonstrations to this README.
- [ ] Explore replacing third-party character content with original characters and artwork.

**Scope:** Local multiplayer is the supported player-versus-player experience. Online multiplayer, Game Center integration, and public App Store distribution are outside the current scope. The roadmap is not a release schedule.

## Public repository and development history

DeckSpawn was originally developed in a **private repository** under the working project name `CardArenaAR`. This public repository begins with a **curated source-code snapshot**: the original private Git history and non-distributable game assets are not included.

A large initial commit therefore represents the **publication of an existing project**, not the entirety of its development in one day. This public repository is now the main codebase for ongoing updates; the original private repository remains a backup of the earlier project and its development assets.

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

DeckSpawn is both a personal experiment and an academic project focused on practical iOS engineering. It brings together **augmented reality, physical input, 3D animation, combat effects, game-state management, UI design, localization, and local multiplayer networking** in a single playable prototype.

**Portfolio:** [See more projects on my website!](www.victorhasse.com)
