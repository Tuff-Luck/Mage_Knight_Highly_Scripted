# Architecture

The project is authored as Lua modules and bundled by Sebastian's Tabletop Simulator VS Code extension into the single Global script that TTS executes. `.tts/objects/Global.lua` is the source entry point; its `require()` order is part of the runtime design.

| Path | Primary responsibility |
| --- | --- |
| `src/Data.lua` | Static game data: cards, monsters, scenarios, GUID mappings and other large lookup tables. |
| `src/ErrorReporting.lua` | Automatic Lua error reporting, protected callback helpers, breadcrumbs and diagnostic context builders. |
| `src/Shared.lua` | Shared helpers used across setup/runtime modules, including protected asynchronous/callback helpers. |
| `src/PlayingGame/DeckCycle.lua` | Shared live-pile lookup and bottom-return cycle tracking for Artifact, Unit, Advanced Action and Spell decks. |
| `src/PlayingGame/AttackAssignments.lua` | Runtime attack-target selection, temporary enemy buttons, and persistent source-to-enemy vector arrows. |
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
| `src/PlayingGame/Quests.lua` | Apocalypse Quest engine, quest state, offer flow, rewards and interactions. Quest-specific legality, combat metadata and resolution effects register through the local handler registry; `ResolveStepAction` is a lifecycle dispatcher over validation and Progress/Complete/Fail phases. |
| `src/PlayingGame/PlayerBoard/CardFlow.lua` | Player deed/deck/discard/hand flow, wound dealing and Glade discard-healing runtime. |
| `src/PlayingGame/PlayerBoard/UnitLayout.lua` | Runtime Unit/Command-slot layout, compression and player-board unit positioning. |
| `src/PlayingGame/PlayerBoard/Events.lua` | Player-board scripting-zone reactions and card presentation helpers dispatched by the global event layer. |
| `src/PlayingGame/PlayerBoard/CardRecognition.lua` | Resource Tracker and Combat Calculator coordinator; owns runtime scan state, player selections, public tracker callbacks and gameplay reconciliation. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/State.lua` | Factory for initial runtime-only private state: scan generations, pending settles/renders, play-area candidates, relocation bookkeeping, highlights and resource-key metadata. The coordinator retains lifecycle reset and saved-state ownership. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/CardEffects.lua` | Played-card and sideways resource records, completion/status, repeated effects and conditional fame/reputation. Uses existing coordinator helpers; scanning, payment discovery, UI, and combat reconciliation remain outside. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/SkillEffects.lua` | Played Skill resource records, dynamic and location-based values, Unit/crystal conditions, completion and status. Reads current game state and uses coordinator choice and combat day/night helpers; physical link resolution is delegated to SkillLinks; lifecycle remains in CardRecognition. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/SkillLinks.lua` | Physical sideways Skill links and mana-conversion links (Polarization), deterministic overlap ranking and shared mana reservations. Consumes coordinator-supplied live zone candidates and permissions; does not discover or consume mana or own UI/target state. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/ActionLinks.lua` | Physical Action pairing for stronger-side grants, Maximal Effect repeats, Ritual Attack throw-away links, mandatory discard costs and Stout Resolve per-use payments. Resolves the existing priority order from live candidates; UI markers, cleanup, choices and record reconciliation stay with CardRecognition. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/UnitEffects.lua` | Numeric resources for selected Unit abilities, Altem Mages mana scaling, Familiar crystal bonuses, combat boosts, Wolf’s Howl and Banner of Glory. Payment discovery, activation history, targeting and record reconciliation stay with CardRecognition; payable selection belongs to UnitChoices. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/UnitChoices.lua` | Payable Unit ability selection, direct and wildcard mana ambiguity, retained paid choices and Banner of Fear selection. Updates existing activation choice bookkeeping; physical payment discovery, history ownership, UI and targeting remain with the coordinator. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/UnitControls.lua` | Unit-specific object UI rendering, collapsed/expanded choice rows, icon assets, combat Move/Psychic variants, separate numeric/effect/Ready targets and missing-control recovery. Reads live combat flags and shared UI caches; click handling, activation history and target assignments remain with CardRecognition. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/ManaPayments.lua` | Independent casting, stronger-effect and elemental-choice payment roles; highest eligible stacked-card selection; Magic Talent, Maximal Effect and Time Bending live play-zone payment scans; Unit mana counting, payment eligibility and change signatures. Public entry points and mana-color permissions stay with CardRecognition; Unit ability decisions are delegated to UnitChoices; activation history remains in the coordinator. Does not discover mana outside the live scripting zone. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/MovementEffects.lua` | Terrain prices, passive Skill ownership, weather modifier records and exploration costs. Reads current scan and saved state; CardRecognition retains public movement-cost entry points. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/ResourceChoices.lua` | Resource option identity, family ranking, printed-side selection, spatial and total-based initial guesses. Reads live selections through the coordinator's accessor; persistence, callbacks, and target handling remain with CardRecognition. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/CardControlOptions.lua` | Card/Skill control option descriptors: fallback choices for fixed effects, repeated and inventory-set rows, deterministic ordering, expanded selection, visible assets and target-button eligibility. Uses coordinator-supplied selection and combat policy; CardControls renders the option descriptors; lifecycle, callbacks and target assignments remain with CardRecognition. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/CardControls.lua` | Card/Skill object UI rendering, option layout and icons, individual and composite target controls, specialized Artifact/Starting Action/Skill controls and XML comparison. Reads live coordinator context; click handlers, assignments and saved gameplay state remain with CardRecognition. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/EnemyAttacks.lua` | Fresh printed enemy Attack records, perk modifiers, elemental conversions, ordered per-Attack reductions and cancellation, summoned-token Attack assembly. Consumes caller-supplied records and selected attack indices; physical enemy lookup, phase state and assignment ownership remain with CardRecognition. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/EnemyDefences.lua` | Enemy traits, Fortification, elemental Resistance, effective Attack totals (including Artifact combat modes), grouped base/Elusive/boss Armour, and application of individual defensive effects to fresh calculator entries. Consumes caller-supplied enemy, resource and effect records; physical lookup, targeting, effect ownership and phase orchestration remain in CardRecognition. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/BlockSolver.lua` | Exact Block and Cumbersome Move allocation, elemental/Psychic Block legality and efficiency, and spent Block totals. Operates on caller-supplied records; CardRecognition owns source collection, result cache, display, target assignment and phase commitments. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/BlockResults.lua` | Block/Move resource collection from assigned sources, result fingerprints and cache entries, successful Block and Move accounting, Shield Bash excess, ineffective Block display and unblocked damage records. Uses BlockSolver and coordinator-supplied callbacks; CardRecognition owns cache lifetime, target assignments and phase commitments. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/BossAllocation.lua` | Boss-level arithmetic and shared ranged/melee Attack allocation across ordinary enemies and boss heads/leaders, including manual corrections, Elusive Armour and previously removed levels. Consumes caller-supplied records and overrides; CardRecognition retains manual override state and phase commitments. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/DefendAllocation.lua` | Phase-aware enemy Defend allocation, grouped target eligibility, survival of ranged-phase defenders, and separate late Armour bonuses. Mutates fresh calculation entries only; uses supplied defensive and Ranged/Siege evaluators. CardRecognition retains physical enemy discovery, target assignments and phase orchestration. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/CombatDisplay.lua` | Combat damage notes, full result text, shared group defence descriptions, melee result formatting, and grouped resource icon distribution. Presentation only; CardRecognition retains actual combat resources, assignments, panel assembly and physical decals. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/DamageResolution.lua` | Ordered Unit/Hero damage allocation, elemental resistance, forced recipients, Poison/Paralyse, Hero mitigation and already-applied destroyed-Unit damage. Consumes caller-supplied records and live lookup callbacks; CardRecognition retains Fortitude history ownership, wound ledger, physical dealing and targeting. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/PhysicalObjects.lua` | Card orientation and physical X/Z geometry, object classification, released-object readiness, mana colour and faction reward identity. Geometry and recognition alone do not authorize mana payments or play-area membership; those policies remain with the coordinator. |
| `src/PlayingGame/PlayerBoard/ResourceTracker/Diagnostics.lua` | Runtime-only opt-in tracker trace buffer, event formatting and admin trace command implementation; initialized by CardRecognition with its existing private state. |
| `src/PlayingGame/PlayerBoard/CombatEffects.lua` | Runtime enemy-targeted Combat Action effects (nearest-enemy linking, Armour/attack modifiers) driven by `enemyEffect` rules in `Data.lua`. |
| `src/PlayingGame/PlayerBoard/Skills.lua` | Skill offers, claims, skill state and player skill interactions. |
| `src/PlayingGame/PlayerBoard/PuppetMaster.lua` | Krang Puppet Master enemy/puppet behaviour. |
| `src/PlayingGame/Combat.lua` | Combat areas, attacks, assaults, combat UI/camera support, summons, pursuit and physical pre-end-turn combat cleanup. While the Combat Calculator runs, Combat also owns the runtime-only defeat marks (red X on tokens the calculator shows defeated; `combatEnemyTokenDefeated` feeds the UI Fame/Rep pass, End Turn uses persisted calculator defeat/partial verdicts without physically flipping tracked tokens, and manual face-down flips are reverted while the calculator is open). The public pre-end-turn path is a phase orchestrator; generic extra-turn/reward sequencing stays in Turn. |
| `src/PlayingGame/FameReputation.lua` | Cross-module Fame/Reputation accounting service used explicitly by Combat, UI, Map, Skills, Turn and Events entry points. |
| `src/PlayingGame/Turn.lua` | Turn progression, reward gates, final-turn boundaries, end-of-round lifecycle, tactics and day/night transitions. End-turn and end-round are explicit phase pipelines rather than monolithic callbacks. |
| `src/PlayingGame/City.lua` | City placement, levels, garrisons, city state and city runtime behaviour; delegates faction-specific work. |
| `src/PlayingGame/FactionLeaders.lua` | Dark Crusader and Elementalist levels, deployment, cooperative previews, combat damage, overkill controls and faction scoring. |
| `src/PlayingGame/BaseScenario.lua` | Shared scenario lifecycle/victory dispatch, original Mage Knight rules, mines, Druid Nights, Dungeon Lords and One to Return. |
| `src/PlayingGame/LLScenario.lua` | Lost Legion scenario runtime: Volkare's Quest/Return, camp-as-city and pursuit helpers. |
| `src/PlayingGame/SOTScenario.lua` | Shades of Tezla scenario-specific rules for Realm of the Dead and Hidden Valley. |
| `src/PlayingGame/APOCScenario.lua` | Apocalypse scenario runtime: Fractured Lands, Horsemen, Dragon, destroyed sites and Fury elite eligibility. |
| `src/PlayingGame/FanScenario.lua` | Fan-created scenario victory rules, including the custom Conquest variants and War of Four. |
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

`Data`, `ErrorReporting`, `Shared` and `PlayingGame.DeckCycle` load first. DeckCycle owns the standard returned-card cycle and live draw-pile lookup used across Quest, Offer, Turn and player-board flows. Shared owns the generic runtime-map geometry/topology primitives (hex keys, adjacency, BFS distance maps, axial conversion and terrain-hex UI placement). Error reporting loads before Shared because the shared async/object helpers use its protected callback machinery. Setup modules then define setup-facing globals. Gameplay modules load after setup; FactionLeaders loads after City and before Combat, with other specialized modules defining systems before the final UI/event/callback layers. `PlayingGame.BaseScenario`, `PlayingGame.LLScenario`, `PlayingGame.SOTScenario`, `PlayingGame.APOCScenario` and `PlayingGame.FanScenario` load together before `PlayingGame.ApocalypseDragon` and `PlayingGame.Horsemen`; specialised encounter modules call scenario-owned hooks at runtime.

Cross-cutting services must not replace another module's global by load order. The owning module should keep the public entry point, give its underlying implementation a unique base name when necessary, and delegate explicitly to the service.

Modules have separate lexical scope for `local` declarations. Globals are shared in the final bundled Global environment. A helper needed by multiple modules should therefore be intentionally global/shared or otherwise exposed once; copying a local helper into several files does not consolidate it.

## TTS object files

The remaining `.tts/objects/*.lua` files may be tiny placeholders even when their former logic has moved to Global. This is intentional: the extension can send an empty/comment-only script to the object and clear stale object-side code.

`.tts/objects/*.data.json` should be treated as object identity/metadata snapshots. They can contain old `LuaScript` and `XmlUI` fields and are not authoritative for source code.

## Generated output

Anything under `.tts/bundled/` is generated by the editor/bundler and is excluded from normal source search/diagnostics. Make code changes in `src/` or the source `.tts/objects` files instead.
