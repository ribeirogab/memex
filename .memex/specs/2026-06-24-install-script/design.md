---
feature: install-script
spec: "[[spec]]"
created: 2026-06-24
---
# Per-project install.sh — Design

> Non-technical write-up of the **already-approved** design — purpose, motivation, definitions, non-goals. Created after design approval as a durable record of *why*; it is **not** a second human-review gate. The technical *how* (architecture, file structure, acceptance criteria) lives in `[[spec]]`.

## Purpose

Give a repo owner a single command that installs memex into a project with everything the Claude Code side needs already wired: the scaffolder skill on disk **and** the marketplace plugin pre-enabled. `install.sh` runs the skills CLI to place the canonical skill under `.agents/skills/memex/`, adds the `.claude/skills/memex` symlink, writes the lockfile, then merges the marketplace + plugin entries into `.claude/settings.json`. After it runs the user opens the repo in their coding agent and runs `/memex` once to audit and scaffold the vault. Two clean responsibilities: **install.sh** sets up the Claude Code surface; **/memex** builds the project memory.

## Motivation

Today the only install path is `npx skills add ribeirogab/memex --skill memex`, and its default behavior for the `claude-code` agent *copies* the skill into `.claude/skills/memex` — no `.agents/` canonical, no symlink — which does not match the intended layout. It also does nothing about the plugin: the `/memex:*` slash commands and companion skills ship from the marketplace plugin, and that only activates once `.claude/settings.json` declares the marketplace and pre-enables `memex@memex`. With the plain command, a fresh install has the scaffolder skill but no plugin until the user runs `/memex` (which writes the settings as a side effect). The install therefore feels half-done: the user sees `/memex` but not `/memex:spec`. A dedicated `install.sh` fixes both gaps in one curl-pipeable command — deterministic target layout plus the plugin wired up front — and tells the user exactly what to do next.

## Definitions

- **Canonical skill copy** — the real skill files at `.agents/skills/memex/` (the open agent-skills standard location), produced by installing against the skills CLI `universal` agent.
- **Agent symlink** — `.claude/skills/memex` → `../../.agents/skills/memex`, so Claude Code discovers the skill without duplicating files.
- **Plugin config** — the two keys merged into `.claude/settings.json`: `extraKnownMarketplaces.memex` (the marketplace source) and `enabledPlugins["memex@memex"] = true`. This is what makes Claude Code install the plugin at workspace-trust time.
- **Dogfood source** — when run inside `ribeirogab/memex` itself (its `.claude-plugin/marketplace.json` declares `name = "memex"`), the marketplace source is `{directory, "."}` instead of `{github, "ribeirogab/memex"}`, matching the skill's own detection.
- **Legacy command cleanup** — removing stale `.claude/commands/memex-{spec,learn,sweep,review-spec}.md` files left by pre-plugin installs.
- **Soft-fail** — if neither `jq` nor `python3` is available, the script does not abort (the skill is already installed); it warns and prints the manual JSON snippet to paste, then exits success.
- **Trust-time install** — `settings.json` only *enables* the plugin; Claude Code downloads and installs it when the user reopens/trusts the workspace. No shell command can force this — `/plugin` is a TUI primitive.

## Non-Goals

- **No change to the `/memex` skill.** It keeps writing `.claude/settings.json` itself as an idempotent fallback — re-running it still repairs the plugin config. install.sh and the skill converge to the same state; neither regresses the other.
- **No forcing of the plugin install.** install.sh stops at writing `settings.json`; the Claude Code trust-time step is inherent and stays the user's action.
- **No multi-agent symlinks.** install.sh wires only the `.claude` surface (matching the intended layout). Other agents (`.codex`, `.cursor`, …) get companion-skill symlinks through the skill when their dirs exist — out of scope here.
- **No new plugin commands or skill content.** This is install plumbing only.
- **No pinning of the skills CLI version.** Uses `npx skills` (latest) to match the README; pinning is a possible later change, not part of this.
