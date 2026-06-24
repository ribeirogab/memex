#!/bin/sh
# memex per-project installer.
#
# Installs the memex scaffolder skill into the current project, enables the
# Claude Code plugin, and guarantees this layout:
#
#   .agents/skills/memex/            <- real skill files (open agent-skills standard)
#   .claude/skills/memex             -> ../../.agents/skills/memex  (symlink)
#   skills-lock.json                 <- skills CLI lockfile
#   .claude/settings.json            <- memex marketplace + plugin enabled
#
# Usage (from your project root):
#   curl -fsSL https://raw.githubusercontent.com/ribeirogab/memex/main/install.sh | sh
#   # or, from a clone:  sh install.sh
#
# Safe to re-run: the skills CLI is idempotent and the symlink + settings merge
# reconcile in place. Tests source this file with MEMEX_INSTALL_LIB=1 to call the
# functions below without running the network install.

set -eu

REPO="ribeirogab/memex"
SKILL="memex"
# The skills CLI installs the canonical copy under .agents/skills/ when targeting
# the agent-agnostic "universal" agent; we add the .claude symlink ourselves.
CANONICAL=".agents/skills/${SKILL}"
LINK=".claude/skills/${SKILL}"

say()  { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- plugin configuration helpers --------------------------------------------

# Marketplace source JSON. Dogfood: inside ribeirogab/memex itself
# (.claude-plugin/marketplace.json declares name = memex) use the local path,
# else the github source. grep keeps this dependency-free (no jq just to pick).
marketplace_source() {
  if [ -f .claude-plugin/marketplace.json ] && \
     grep -Eq '"name"[[:space:]]*:[[:space:]]*"memex"' .claude-plugin/marketplace.json; then
    printf '{"source":"directory","path":"."}'
  else
    printf '{"source":"github","repo":"%s"}' "$REPO"
  fi
}

# Which JSON tool merges settings: jq > python3 > none (the soft-fail signal).
plugin_merge_engine() {
  if command -v jq >/dev/null 2>&1; then printf 'jq'
  elif command -v python3 >/dev/null 2>&1; then printf 'python3'
  else printf 'none'; fi
}

# Human-pasteable settings.json object for the soft-fail path.
plugin_snippet() {
  src="$1"
  printf '%s\n' '{'
  printf '  "extraKnownMarketplaces": { "memex": { "source": %s } },\n' "$src"
  printf '%s\n' '  "enabledPlugins": { "memex@memex": true }'
  printf '%s\n' '}'
}

# Merge the two keys into $1, preserving every other top-level key. The mktemp
# copy avoids reading and truncating the same file in one redirect.
merge_with_jq() {
  settings="$1"; src="$2"; tmp="$(mktemp)"
  if [ -s "$settings" ]; then cp "$settings" "$tmp"; else printf '{}' > "$tmp"; fi
  jq --argjson src "$src" '
    .extraKnownMarketplaces["memex"] = { "source": $src }
    | .enabledPlugins["memex@memex"] = true
  ' "$tmp" > "$settings"
  rm -f "$tmp"
}

merge_with_python() {
  MEMEX_SETTINGS="$1" MEMEX_SRC="$2" python3 - <<'PY'
import json, os, pathlib
p = pathlib.Path(os.environ["MEMEX_SETTINGS"])
src = json.loads(os.environ["MEMEX_SRC"])
data = json.loads(p.read_text()) if p.exists() and p.read_text().strip() else {}
data.setdefault("extraKnownMarketplaces", {})["memex"] = {"source": src}
data.setdefault("enabledPlugins", {})["memex@memex"] = True
p.write_text(json.dumps(data, indent=2) + "\n")
PY
}

# Enable the Claude Code plugin by merging marketplace + enabledPlugins into
# .claude/settings.json. Soft-fail (no abort) when no JSON tool is available.
configure_plugin() {
  settings=".claude/settings.json"
  src="$(marketplace_source)"
  mkdir -p .claude
  case "$(plugin_merge_engine)" in
    jq)      merge_with_jq "$settings" "$src" ;;
    python3) merge_with_python "$settings" "$src" ;;
    *)
      say "warning: neither jq nor python3 found — plugin not auto-configured."
      say "Add this to ${settings} manually:"
      plugin_snippet "$src"
      return 0
      ;;
  esac
  say "Enabled memex plugin in ${settings}"
}

# Remove pre-plugin leftover command files (missing files are not an error).
remove_legacy_commands() {
  for cmd in memex-spec memex-learn memex-sweep memex-review-spec; do
    rm -f ".claude/commands/${cmd}.md"
  done
}

print_next_steps() {
  say ""
  say "memex installed:"
  say "  ${CANONICAL}/"
  say "  ${LINK} -> ../../.agents/skills/${SKILL}"
  say "  skills-lock.json"
  say "  .claude/settings.json (memex marketplace + plugin enabled)"
  say ""
  say "Next: open this repo in your coding agent and run  /memex"
  say "  (audits the memex and scaffolds whatever is missing)"
  say ""
  say "The memex plugin (/memex:spec, /memex:new-pr, ...) installs when Claude Code"
  say "trusts this workspace — reopen the repo or accept the trust prompt."
}

# --- install flow ------------------------------------------------------------

run_install() {
  command -v npx >/dev/null 2>&1 || fail "npx not found. Install Node.js (https://nodejs.org) and retry."

  say "Installing ${SKILL} skill from ${REPO} ..."
  # </dev/null: under `curl ... | sh` stdin IS the script source; npx/skills would
  # otherwise drain it, swallowing every line below.
  npx -y skills add "${REPO}" --skill "${SKILL}" -a universal -y </dev/null

  [ -f "${CANONICAL}/SKILL.md" ] || fail "skills CLI did not produce ${CANONICAL}/SKILL.md"

  mkdir -p ".claude/skills"
  if [ -L "${LINK}" ]; then
    rm -f "${LINK}"
  elif [ -e "${LINK}" ]; then
    fail "${LINK} exists and is not a symlink. Remove it and re-run."
  fi
  ln -s "../../.agents/skills/${SKILL}" "${LINK}"

  [ -L "${LINK}" ]          || fail "${LINK} is not a symlink"
  [ -f "${LINK}/SKILL.md" ] || fail "${LINK} does not resolve to the skill"
  [ -f "skills-lock.json" ] || fail "skills-lock.json was not created"

  remove_legacy_commands
  configure_plugin
  print_next_steps
}

# Run only when executed, not when sourced (tests source with MEMEX_INSTALL_LIB=1).
[ "${MEMEX_INSTALL_LIB:-0}" = "1" ] || run_install
