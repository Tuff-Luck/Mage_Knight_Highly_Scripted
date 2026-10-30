# Contributing

Thanks for helping improve the Mage Knight Highly Scripted mod. This guide describes the contribution workflow for people and AI coding tools. It focuses on how to make, validate, and hand off changes; the project-specific implementation rules live in `AGENTS.md`, and the module map lives in `ARCHITECTURE.md`.

## Before you start

1. Read `AGENTS.md` and `ARCHITECTURE.md` before changing project files. Follow their current guidance.
2. Check the repository, branch, and working-tree status. Do not overwrite or discard existing work.
3. Make sure you understand the issue or requested behaviour. For gameplay changes, verify the relevant Mage Knight rule/card/scenario details rather than guessing.
4. Find the owning module in `ARCHITECTURE.md`, then inspect the implementation and its callers before editing.
5. If the requested behaviour is materially ambiguous, clarify it before making a gameplay or architecture decision.

Keep each change focused. Avoid unrelated refactoring, generated-file edits, and changes to established behaviour that are not required by the task.

## Branches and changes

- Do feature work on a dedicated branch rather than directly on the release/default branch, unless the maintainer asks otherwise.
- Give the branch a short name that describes the work, for example `fix/quest-reward-check` or `feature/new-hero`.
- Keep a branch focused on one logical task where practical.
- If a bug fix is also needed on another active branch, make the fix in a way that can be cleanly merged or cherry-picked; do not assume work on one branch automatically appears on another.
- Before merging, bring the target branch up to date and resolve conflicts deliberately. Re-check the resulting diff after conflict resolution.
- Do not force-push, rewrite shared history, delete branches, or merge/revert pull requests unless explicitly authorised.

Preserve local changes made by the maintainer or another contributor. If unrelated changes are present, leave them untouched and mention them in the handoff.

## Making code changes

- Edit authoritative source files under `src/` and source object files under `.tts/objects/` as appropriate.
- Do not edit generated output under `.tts/bundled/`; regenerate it through the normal project build workflow when needed.
- Edit UI panels in `src/UI/`, not the include-only `.tts/objects/Global.xml`.
- Follow the module ownership and dependency guidance in `ARCHITECTURE.md`.
- Keep Tabletop Simulator compatibility at Lua 5.2.
- Prefer the smallest coherent implementation that fits the existing architecture.
- Reuse existing shared helpers and protected asynchronous boundaries rather than introducing duplicate implementations.
- Do not add backwards-compatibility or old-save migration code unless the task explicitly calls for it.
- Follow the gameplay automation philosophy in `AGENTS.md`: automation should generally help, remind, and warn rather than overrule a player's physical choice. Only enforce hard constraints where the project rules or script invariants clearly require it.
- Do not use translated display text as program identity. Follow the stable identity and localization conventions in `AGENTS.md`.

For a new Mage Knight character, scenario, card, or other content addition, inspect the existing equivalent implementations and data structures first. Keep static game data, runtime behaviour, UI, setup, and scoring in their documented owning modules rather than placing everything in one file.

## Validation and testing

Run the project validator from the repository root in PowerShell:

```powershell
.\tools\validate-project.ps1
```

For a local environment that must explicitly require Lua 5.2 parsing:

```powershell
.\tools\validate-project.ps1 -RequireLua52
```

The validator checks project structure, JSON/XML validity and include resolution, module requires, duplicate global functions, selected risky local-state patterns, Lua 5.2 syntax (when a compatible compiler is available or required), and Git whitespace errors. See the Validation section in `AGENTS.md` for the exact current checks and limitations.

Also run focused tests or manual checks appropriate to the change:

- Exercise affected behaviour in Tabletop Simulator when runtime behaviour changes.
- Check relevant setup, turn, combat, save/load, and UI paths where they could be affected.
- For UI/localization changes, check the panel in TTS and verify translated text is restored correctly.
- For scenario/card data changes, verify the canonical data and the behaviour that consumes it.

A successful validator run is not proof that the feature works in TTS. State clearly which checks were run, which passed, and which could not be performed. Never report an unrun test as passing.

## Commits

Use clear, imperative commit messages that describe the change, for example:

- `Fix Quest reward completion check`
- `Add new hero setup data`
- `Update Node.js workflow to v24`

Prefer one commit per logical change. Do not include unrelated formatting, generated output, temporary debugging changes, or local configuration.

Before committing, review:

```powershell
git status --short
git diff --check
git diff
```

If changes are already staged, inspect those too:

```powershell
git diff --cached --check
git diff --cached
```

## Pull requests and review

A pull request should make it easy to understand what changed and how it was checked. Include:

- **Purpose:** the problem being solved or feature being added.
- **Behaviour:** the important user/gameplay-visible changes.
- **Implementation:** the main modules or data files changed, and any important design decisions.
- **Validation:** the exact validator/test/manual checks run and their results.
- **Limitations:** anything not tested, known edge cases, assumptions, or follow-up work.

Keep the PR focused and review the complete diff against its target branch. Resolve conflicts without dropping either branch's intended behaviour. Do not merge your own PR unless you have permission under the project's current review process.

## AI-assisted contributions

AI tools are welcome, but they must follow the same project rules as human contributors.

- Treat `AGENTS.md`, `ARCHITECTURE.md`, and the current source on the working branch as authoritative.
- Do not rely on an old conversation, generated summary, or stale copy of a file in place of inspecting the repository.
- Do not invent game rules, card effects, scenario requirements, or Tabletop Simulator API behaviour.
- Ask before making a material gameplay/design choice that is not established by the project.
- Do not silently broaden the task, remove existing behaviour, or perform unrelated cleanup.
- Clearly disclose AI-generated or AI-assisted changes when required by the maintainer or review process.
- Provide a useful handoff: summarise the changes, list affected files, explain non-obvious decisions, and report validation accurately.

## Questions and uncertain rules

When a rule, card interaction, scenario exception, or intended automation behaviour is uncertain, do not resolve it by assumption. Identify the exact uncertainty and ask the maintainer, or use an authoritative game/project reference that has been provided for the task. Preserve the existing behaviour until the intended rule is clear.
