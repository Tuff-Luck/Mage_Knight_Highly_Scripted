# Architecture

The project is authored as Lua modules and bundled by Sebastian's Tabletop Simulator VS Code extension into the single Global script that TTS executes. `.tts/objects/Global.lua` is the source entry point; its `require()` order is part of the runtime design.

| Path | Primary responsibility |
| --- | --- |
| `src/Data.lua` | Static game data: cards, monsters, scenarios, GUID mappings and other large lookup tables. |
| `src/ErrorReporting.lua` | Automatic Lua error reporting, protected callback helpers, breadcrumbs and diagnostic context builders. |
| `src/Shared.lua` | Shared helpers used across setup/runtime modules, including protected asynchronous/callback helpers. |
| `src/SetupInterface.lua` | Setup menu/UI state, scenario/variant option presentation, cross-option locks and setup-facing controls. |
| `src/SetupGame.lua` | Setup orchestration: Start handling, final option normalization, delayed completion and setup callback boundary. |
| `src/SetupGame/Components.lua` | Monster pools and setup-time expansion bag merging. |
| `src/SetupGame/Players.lua` | Physical player, Dummy and Volkare board/piece deployment. |
| `src/SetupGame/Decks.lua` | Deck construction, shuffling and setup-time card-pool preparation. |
| `src/SetupGame/HigherLevel.lua` | Start-at-higher-level setup and temporary player pools. |
| `src/SetupGame/HeroChallenges.lua` | Hero Challenge legality, terrain assignment and setup-facing objective helpers. |
| `src/SetupGame/Map.lua` | Starting-map construction, terrain-stack building and setup-only Fury lair placement. |
| `src/PlayingGame/Map.lua` | Map state, avatar location, terrain placement/population, exploration, shield placement, terrain-site helpers and rampaging-enemy placement. |
| `src/PlayingGame/MapTokens.lua` | Runtime-only physical map-token arrival, shared-hex stacking/separation and deterministic token layout. |
| `src/PlayingGame/Offers.lua` | Artifact, Unit, Monastery and deed-offer layout/refill runtime. |
| `src/PlayingGame/TokenPools.lua` | Monster token-pool refill plus bag scaling/discard-stack presentation. |
| `src/PlayingGame/ManaSource.lua` | Shared/mirrored Mana Source dice state and synchronization. |
| `src/PlayingGame/Quests.lua` | Apocalypse Quest system, quest state, offer flow, rewards and quest-specific interactions. |
| `src/PlayingGame/PlayerBoard/CardFlow.lua` | Player deed/deck/discard/hand flow, wound dealing and Glade discard-healing runtime. |
| `src/PlayingGame/PlayerBoard/UnitLayout.lua` | Runtime Unit/Command-slot layout, compression and player-board unit positioning. |
| `src/PlayingGame/PlayerBoard/Events.lua` | Player-board scripting-zone reactions and card presentation helpers dispatched by the global event layer. |
| `src/PlayingGame/PlayerBoard/Skills.lua` | Skill offers, claims, skill state and player skill interactions. |
| `src/PlayingGame/PlayerBoard/PuppetMaster.lua` | Krang Puppet Master enemy/puppet behaviour. |
| `src/PlayingGame/Combat.lua` | Combat areas, attacks, assaults, combat UI/camera support, summons, pursuit and physical pre-end-turn combat cleanup. The public pre-end-turn path is a phase orchestrator; generic extra-turn/reward sequencing stays in Turn. |
| `src/PlayingGame/FameReputation.lua` | Cross-module Fame/Reputation accounting service used explicitly by Combat, UI, Map, Skills, Turn and Events entry points. |
| `src/PlayingGame/Turn.lua` | Turn progression, reward gates, final-turn boundaries, end-of-round lifecycle, tactics and day/night transitions. End-turn and end-round are explicit phase pipelines rather than monolithic callbacks. |
| `src/PlayingGame/City.lua` | City placement, levels, garrisons, city state and city runtime behaviour. |
| `src/PlayingGame/Scenario.lua` | Scenario-specific runtime rules and scenario state transitions, including Fury elite-unit eligibility. |
| `src/PlayingGame/ApocalypseDragon.lua` | Shared Apocalypse Dragon infrastructure for all Dragon scenarios: head levels/setup, landed Dragon combat, common choice helpers, and the interstitial Dragon-turn shell shared by Against the Dragon and Fury. |
| `src/PlayingGame/Horsemen.lua` | Shared Four Horsemen entity/combat layer for Against the Horsemen and Apocalypse is Here: level projection, individual attacks/defeats, shared restore state and defeat summaries. |
| `src/PlayingGame/Scoring.lua` | End-game and scenario scoring. |
| `src/PlayingGame/AI/Common.lua` | Shared automated-player helpers. |
| `src/PlayingGame/AI/Proxy.lua` | Apocalypse Proxy Player behaviour and choice flow. |
| `src/PlayingGame/AI/Dummy.lua` | Standard Dummy player behaviour. |
| `src/PlayingGame/AI/Volkare.lua` | Volkare movement, combat and scenario AI. |
| `src/PlayingGame/Movement.lua` | Movement calculator, route/terrain costs and teleport movement assistance. |
| `src/PlayingGame/Rollers.lua` | Centralized Roll Crystal Die/object roller behaviour. |
| `src/PlayingGame/UI.lua` | Runtime presentation, camera controls, ALT views, resource/UI helpers and object UI installers. `mainUIUpdate()` is a coalesced dispatcher over focused refresh domains; expensive combat Fame/Reputation reconciliation is skipped only for explicitly non-combat sources. |
| `src/PlayingGame/Events.lua` | Thin TTS event handling, maintenance/persistence support and runtime event dispatch. |
| `src/PlayingGame/Telemetry.lua` | Opt-in statistics, bug-report and score-report payload construction/submission. |
| `src/PlayingGame/Callbacks.lua` | Public/safe callback boundaries exposed to TTS/UI entry points, including final `onLoad` composition. |

## Dependency shape

`Data`, `ErrorReporting` and `Shared` load first. Shared owns the generic runtime-map geometry/topology primitives (hex keys, adjacency, BFS distance maps, axial conversion and terrain-hex UI placement). Error reporting loads before Shared because the shared async/object helpers use its protected callback machinery. Setup modules then define setup-facing globals. Gameplay modules load after setup, with specialized modules defining their systems before the final UI/event/callback layers. `PlayingGame.Scenario` loads immediately before `PlayingGame.ApocalypseDragon` and `PlayingGame.Horsemen`; both shared encounter modules call scenario-owned hooks only at runtime.

Cross-cutting services must not replace another module's global by load order. The owning module should keep the public entry point, give its underlying implementation a unique base name when necessary, and delegate explicitly to the service.

Modules have separate lexical scope for `local` declarations. Globals are shared in the final bundled Global environment. A helper needed by multiple modules should therefore be intentionally global/shared or otherwise exposed once; copying a local helper into several files does not consolidate it.

## TTS object files

The remaining `.tts/objects/*.lua` files may be tiny placeholders even when their former logic has moved to Global. This is intentional: the extension can send an empty/comment-only script to the object and clear stale object-side code.

`.tts/objects/*.data.json` should be treated as object identity/metadata snapshots. They can contain old `LuaScript` and `XmlUI` fields and are not authoritative for source code.

## Generated output

Anything under `.tts/bundled/` is generated by the editor/bundler and is excluded from normal source search/diagnostics. Make code changes in `src/` or the source `.tts/objects` files instead.
