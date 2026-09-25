# Working Rules for Agents

## Source authority

The authoritative project code is under `src/`, with `.tts/objects/Global.lua` as the bundler entry point and `.tts/objects/Global.xml` as the Global UI source.

Files under `.tts/objects/*.data.json` are object metadata snapshots. Their embedded `LuaScript`, `LuaScriptState`, and `XmlUI` fields can be stale and must never be used as the source of current code. A compiled Tabletop Simulator save JSON is also reference material for objects/layout only unless the user explicitly says otherwise.

`.tts/bundled/` is generated output. Do not edit generated bundled files as source.

## Git workflow

Work on the repository's current default branch unless the user explicitly requests another branch. Before writing to a named branch, verify that it still exists; do not rely on historical branch names.

Keep changes focused. Prefer one clean commit for one logical change. Do not add temporary workflow/history commits to the final branch when a clean tree/commit can be produced instead.

## Lua and module rules

Tabletop Simulator compatibility is validated against Lua 5.2. Do not introduce syntax that requires a newer Lua version.

Keep shared helpers defined once. Cross-system helpers belong in `src/Shared.lua` or another clearly owned module; do not duplicate implementations in multiple modules. `require()` does not merge duplicate local functions.
Default file-private helpers to `local function`; keep a function global only when TTS/UI must resolve it by name or another module intentionally calls it as part of that subsystem's public API.
Do not use late module loading to redefine an existing global callback/helper. For cross-cutting behavior, keep one public owner entry point and delegate explicitly to a uniquely named service/base implementation so ownership and call order remain visible and duplicate-global validation stays meaningful.
Keep `mainUIUpdate()` as a coalesced UI dispatcher. Put new presentation work in the narrowest existing refresh domain instead of growing the dispatcher; only bypass a domain for named sources that provably cannot change that domain’s state, with unknown sources always taking the full refresh path.
Keep turn lifecycle callbacks thin. `endTurn` should read as reward gates → per-turn reset → transition; `endRound` should read as checkpoint/interrupts → world refresh → offers/pieces/decks → turn order/tactics → hand deal. Physical combat-object cleanup remains owned by Combat, while generic turn choices and reward sequencing belong in Turn.

Respect module ownership documented in `ARCHITECTURE.md`. When a feature already has a module, make the change there rather than adding another implementation to `PlayingGame.lua`.

Require order in `.tts/objects/Global.lua` matters. `ErrorReporting` loads before `Shared` so shared async/object helpers can use its protected callback machinery. `PlayingGame.Callbacks` loads after UI and Events because its public lifecycle callbacks compose helpers defined by those modules.

Functional object Lua should be moved into Global modules where practical. Placeholder object Lua files may remain so Sebastian's TTS extension clears old object-side scripts when compiling.

Use the existing protected asynchronous boundaries (`safeWaitFrames`, `safeWaitTime`, `safeWaitCondition`, `safeTakeObject`, `safeSpawnObject`, and related helpers) rather than introducing raw delayed/callback boundaries without a reason.

During game setup, never use a fixed time/frame delay to order dependent setup steps when the real dependency can be observed. Chain setup through object callbacks or `safeWaitCondition` checks for the actual requirement (registration, resting/movement completion, container contents, state change, or subsystem-ready flag). Fixed delays are acceptable only for terminal/cosmetic post-setup work that does not gate, supply, or protect another setup step. Visual map setup may remain deliberately paced, but its completion must be signaled explicitly rather than inferred from elapsed time.

Prefer compact Lua and direct changes. Add nil guards when they prevent a real runtime problem or improve diagnosis; do not blanket the code with defensive guards.

For visible scripted movement, use Tabletop Simulator\'s normal/slow smooth movement by default. Pass `fast=false` explicitly (`setPositionSmooth(..., false, false)` / `setRotationSmooth(..., false, false)`) when touching movement code so the intent is unambiguous. Do not use the fast smooth-move mode unless the user explicitly asks for it. Container `takeObject({smooth=true})` is fine when extracting an object; do not replace normal visible movement with fast smooth movement.

Do not add backwards-compatibility or old-save recovery code unless the user explicitly requests it.

## Gameplay automation philosophy

**Scripts should help, remind, and warn — not prevent.** When a player action may depend on an ambiguous rule, table ruling, optional interpretation, or deliberate manual correction, preserve the player's physical choice and continue the normal bookkeeping/automation. Give a concise warning or reminder when useful, but do not silently undo the action, disable the relevant control, pause the subsystem, or otherwise force the script's interpretation.

Use hard prevention only when it protects a mechanical/script invariant, prevents an impossible or corrupt state, or implements an unambiguous rule the project explicitly intends to enforce. When the physical table clearly shows a deliberate player choice, prefer assisting that state over overruling it. Soft safeguards such as the Rewards Claimed reminder pattern are preferred whenever player judgment can resolve the situation.

For Apocalypse Quests, the old Google Sheet / Quest summary sheet used during initial implementation is out of date and is not an authority. Audit and change the current Lua/card behavior directly; do not re-import or “correct” rules from that sheet.
Put Quest-specific exceptions and resolution effects on the per-Quest handler registry instead of adding new GUID chains to generic Quest lifecycle functions. Keep shared Quest progression/offer/cleanup orchestration generic.
Keep `apocalypseQuestResolveStepAction()` as the thin Quest resolution lifecycle: wait/validate → rewind boundary → action-specific resolver. Add new Progress/Complete/Fail behavior to the narrow action resolver or Quest handler rather than growing the dispatcher.


## Persistent state and source of truth

Treat the physical Tabletop Simulator table as the source of truth for game-world facts **only when the current saved table state represents that fact unambiguously**. Players may unlock and manually move pieces despite script guidance; when they do, their physical arrangement is authoritative unless the rules require hidden/history state that the table cannot express.

Do not automatically mirror reconstructable table state into `gStates`. Derived indexes, map graphs, object-location caches, revealed-object scans, and similar runtime conveniences should normally be rebuilt from the table and kept out of saved JSON.

Audit `gStates` slowly and conservatively. Before removing any saved field, ask whether an arbitrary save can reconstruct the same underlying fact correctly from the physical table **at every legal save point**, including midway through turns, combat, scripted movement, setup transitions, and temporary presentation/layout states. If the visible object can be temporarily moved away from the location/state that the field represents, the field may still be required.

For example, do **not** assume `gStates.monsterPlayLocation` is reconstructable from a monster's current position: a save taken during combat may have that monster temporarily sitting on a player board while its map origin still needs to be remembered.

In general:
- Save player/setup decisions, hidden history, once-only flags, unresolved sequence/choice state, and any logical state that cannot be recovered unambiguously from an arbitrary physical save.
- Prefer the table for stable physical facts such as objects that remain in their meaningful game location/state throughout play.
- Keep derived runtime caches outside `gStates` and rebuild them after load.
- When saved metadata and the stable physical table genuinely disagree because a player deliberately changed the table, prefer the table unless that metadata represents hidden/history state rather than duplicated physical state.


### Shared runtime digital map

Movement, Proxy/AI, Quests, Map avatar scans and Combat now share the rebuildable runtime map derived from the physical table. Do not create another saved `gStates` copy of this map.

- `runtimeMapSnapshot()` owns revealed terrain/feature data, exact hex centres and cached neighbour topology.
- `runtimeMapSpatialSnapshot()` overlays fresh physical-object positions and spatial buckets for live shields, enemies, avatars and other map pieces. It is deliberately runtime-only so moving a piece on the table remains authoritative.
- Runtime changes to a terrain hex's logical feature/type must go through `runtimeMapSetHexFeature()` / `runtimeMapSetHexType()`. Do not write `terrainTiles[...].hexFeature/hexType` directly during play, because the shared topology cache must be invalidated with the mutation.
- Generic map identity/geometry belongs in Shared: use `runtimeMapHexKey()`, `runtimeMapHexesAdjacent()`, `runtimeMapHexDistanceMap()`, `runtimeMapWorldToAxial()`, `runtimeMapAxialToWorld()`, `runtimeMapWorldHexDistance()`, and `runtimeMapHexForPosition()` instead of subsystem-prefixed copies.
- `PlayingGame/MapTokens.lua` owns runtime-only arrival ordering and physical shared-hex token separation/stacking; scenario modules should call it rather than reimplementing token layout.
- `pursuingRampagers()` and Combat's nearby attack/shield checks use the shared topology/spatial view instead of rescanning the full map.
- End-of-combat scenario completion state should continue to prefer explicit scenario/runtime state when that represents hidden or historical information; use the spatial map only for facts that are physically represented on the table.

Keep these as derived-runtime optimizations. The physical table remains authoritative, and the digital map must be rebuildable after load.

## Blitz scenario conventions

The Blitz representation predates most custom scenarios. It was introduced because **Conquest** has genuinely different scenario values when Blitz is enabled (for example rounds, terrain counts/map shape and city levels), so Blitz cannot be treated only as a generic setup flag.

`scenarioList` may therefore contain a normal row such as `"Conquest"` and a separate sibling row such as `"Conquest Blitz"`. The setup UI toggles between matching sibling rows by adding/removing the literal `" Blitz"` suffix when such a row exists. Treat `gStates.gameScenario` as the selected scenario identity: a Blitz-named row may contain materially different per-player setup data and scenario text.

`gStates.blitz` is the separate common Blitz rules/setup switch. When active it supplies the shared Blitz package (including the Blitz Fame board, an extra Mana Source die, an extra Unit in the offer, and the Blitz starting Fame/Reputation adjustment). Do **not** replace explicit Blitz scenario rows by calculating their rounds, terrain counts, city levels, map shape, or other scenario-specific values from the normal row; those values belong in `scenarioList`.

Use `scenarioDetails.blitzPossible` as scenario metadata:
- `"Yes"` means the scenario is designed to have selectable normal and Blitz forms and should have the appropriate sibling data rows.
- `"On Only"` means Blitz is the intended/required form for that scenario entry.
- `"Off Only"` means the scenario is intended to run without Blitz.

Do not assume every scenario should eventually have both normal and Blitz versions. The system was built to allow that possibility, but many scenarios only have one intended form. In particular, a scenario whose canonical internal name already ends in `" Blitz"` may simply be an on-only scenario, not evidence that a non-Blitz implementation is missing.

When writing scenario-specific runtime code, match the actual `gStates.gameScenario` names represented in `scenarioList`. If behavior is genuinely shared by a normal/Blitz pair, handle both names explicitly or factor a small helper when repetition warrants it. Do not strip `" Blitz"` and assume the two variants are otherwise interchangeable. Conversely, do not create duplicate normal/Blitz branches when the only difference is already covered by the common `gStates.blitz` setup package.

When adding a new scenario, choose its Blitz model deliberately: off-only, on-only, or a true selectable pair. Only add a second scenario row when the Blitz form needs its own scenario data/rules rather than merely the shared Blitz bonuses.

## Canonical game data

Do not use translated display strings as program identity or parse them to infer rules. Store a stable canonical key beside translated presentation text and branch on the key. Map shape logic specifically uses `mapShapeKey`; `mapShape` is display text only.

## UI localization

In the current Tabletop Simulator version targeted by this project, XML/UI `tooltip` attributes do **not** process the `{en}`, `{ru}`, `{zh-tw}`, etc. translation-tag format. Tagged tooltip strings are shown literally. Keep tooltips as plain English unless Tabletop Simulator adds working tooltip localization in a later version and it is explicitly re-tested.

This limitation applies both to tooltips declared in `Global.xml` and tooltips assigned at runtime with `UI.setAttribute(..., "tooltip", ...)`. Do not add translation tags to either form.

The script does not manage a player's internal Move/Combat/Interact phases. Do not classify missing phase enforcement as a bug unless a scripted helper gives incorrect guidance or changes game state incorrectly.

## Dummy and Proxy City shields

The Dummy player and Proxy Player do **not** use the same friendly-City shield rule.

- **Dummy:** never place a Dummy shield on a friendly City.
- **Proxy Player:** may place its shield on a friendly City according to the Proxy rules.

Do not copy Proxy shield-placement behavior into Dummy logic, and do not treat a missing Dummy shield on a friendly City as a bug.

## Rewards Claimed lock rules

“Use the Rewards Claimed lock” means a soft player-action safeguard, not a disabled button. Keep **Rewards Claimed** clickable; while the lock is active, clicking it should explain the unresolved action and leave the turn at the reward stage.

Add a short matching reminder to the reward checklist above the button so it completes **“Have you:-”**. Move the clicking player's camera to the problem area when there is a useful physical target (for example the map, Quest area, offer, or play area). If there is no useful camera target, leave the camera alone.

A Rewards Claimed soft lock lasts **30 seconds** from when **Rewards Claimed becomes available after any short scripted cleanup/settling delay**. While an authoritative reminder condition is still outstanding during that window, give the **Rewards Claimed** button a faint orange tint so the player can see that it is in the soft-locked state. After that window expires, the button must allow progression even if the reminder condition is still unresolved, and the tint must clear. The reminder may remain visible while the condition remains true.

Only use a Rewards Claimed lock when the script has authoritative state that the required action is outstanding. Do not infer a mandatory action from ambiguous card movement or from rewards that may have multiple reasons for being claimed.

Hard-disable **Rewards Claimed** only for short asynchronous/script-settling safety windows where player input cannot resolve the condition; those are not Rewards Claimed locks and do not need a **“Have you:-”** reminder.

## Build/version conventions

When producing numbered release files, keep the Global Lua and Global XML build numbers matched whenever both change. The automatic Lua Error Reporter version must match the Global Lua build number in brackets.

Do not bump a numbered release solely because source modules are being reorganized unless the user asks for a compiled numbered release.

## Validation

Run `tools/validate-project.ps1` before considering a structural change complete. GitHub CI runs the same validator with Lua 5.2 required.

Validation should cover source Lua syntax, object Lua syntax, JSON parsing, TTS XML fragment parsing, Global `require()` resolution, and whitespace errors.

## Safe TTS desktop workflow

When syncing a machine that already has an older TTS save: load TTS and the mod first, then pull Git changes, then compile/send the current source from VS Code. Do not save the still-old TTS scripts back over freshly pulled source before compiling.
