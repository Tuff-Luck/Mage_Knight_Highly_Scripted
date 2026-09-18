# Working Rules for Agents

## Source authority

The authoritative project code is under `src/`, with `.tts/objects/Global.lua` as the bundler entry point and `.tts/objects/Global.xml` as the Global UI source.

Files under `.tts/objects/*.data.json` are object metadata snapshots. Their embedded `LuaScript`, `LuaScriptState`, and `XmlUI` fields can be stale and must never be used as the source of current code. A compiled Tabletop Simulator save JSON is also reference material for objects/layout only unless the user explicitly says otherwise.

`.tts/bundled/` is generated output. Do not edit generated bundled files as source.

## Git workflow

During the modular refactor, work on `modular-refactor` unless the user explicitly requests another branch. Do not modify `main` unless explicitly requested.

Keep changes focused. Prefer one clean commit for one logical change. Do not add temporary workflow/history commits to the final branch when a clean tree/commit can be produced instead.

## Lua and module rules

Tabletop Simulator compatibility is validated against Lua 5.2. Do not introduce syntax that requires a newer Lua version.

Keep shared helpers defined once. Cross-system helpers belong in `src/Shared.lua` or another clearly owned module; do not duplicate implementations in multiple modules. `require()` does not merge duplicate local functions.

Respect module ownership documented in `ARCHITECTURE.md`. When a feature already has a module, make the change there rather than adding another implementation to `PlayingGame.lua`.

Require order in `.tts/objects/Global.lua` matters. `ErrorReporting` loads before `Shared` so shared async/object helpers can use its protected callback machinery. `PlayingGame.Callbacks` loads after UI and Events because its public lifecycle callbacks compose helpers defined by those modules.

Functional object Lua should be moved into Global modules where practical. Placeholder object Lua files may remain so Sebastian's TTS extension clears old object-side scripts when compiling.

Use the existing protected asynchronous boundaries (`safeWaitFrames`, `safeWaitTime`, `safeWaitCondition`, `safeTakeObject`, `safeSpawnObject`, and related helpers) rather than introducing raw delayed/callback boundaries without a reason.

Prefer compact Lua and direct changes. Add nil guards when they prevent a real runtime problem or improve diagnosis; do not blanket the code with defensive guards.

Do not add backwards-compatibility or old-save recovery code unless the user explicitly requests it.

The script does not manage a player's internal Move/Combat/Interact phases. Do not classify missing phase enforcement as a bug unless a scripted helper gives incorrect guidance or changes game state incorrectly.

## Build/version conventions

When producing numbered release files, keep the Global Lua and Global XML build numbers matched whenever both change. The automatic Lua Error Reporter version must match the Global Lua build number in brackets.

Do not bump a numbered release solely because source modules are being reorganized unless the user asks for a compiled numbered release.

## Validation

Run `tools/validate-project.ps1` before considering a structural change complete. GitHub CI runs the same validator with Lua 5.2 required.

Validation should cover source Lua syntax, object Lua syntax, JSON parsing, TTS XML fragment parsing, Global `require()` resolution, and whitespace errors.

## Safe TTS desktop workflow

When syncing a machine that already has an older TTS save: load TTS and the mod first, then pull Git changes, then compile/send the current source from VS Code. Do not save the still-old TTS scripts back over freshly pulled source before compiling.
