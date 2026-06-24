#!/bin/sh
# memex per-project installer.
#
# Installs the memex scaffolder skill into the current project and guarantees the
# canonical layout:
#
#   .agents/skills/memex/            <- real skill files (open agent-skills standard)
#   .claude/skills/memex             -> ../../.agents/skills/memex  (symlink)
#   skills-lock.json                 <- skills CLI lockfile
#
# Usage (from your project root):
#   curl -fsSL https://raw.githubusercontent.com/ribeirogab/memex/main/install.sh | sh
#   # or, from a clone:  sh install.sh
#
# Safe to re-run: the skills CLI is idempotent and the symlink is reconciled in place.

set -eu

REPO="ribeirogab/memex"
SKILL="memex"
# The skills CLI installs the canonical copy under .agents/skills/ when targeting
# the agent-agnostic "universal" agent; we add the .claude symlink ourselves.
CANONICAL=".agents/skills/${SKILL}"
LINK=".claude/skills/${SKILL}"

say()  { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- prerequisites -----------------------------------------------------------
command -v npx >/dev/null 2>&1 || fail "npx not found. Install Node.js (https://nodejs.org) and retry."

# --- install the skill (canonical .agents/ copy + skills-lock.json) ----------
say "Installing ${SKILL} skill from ${REPO} ..."
# </dev/null: when this script is run via `curl ... | sh`, stdin IS the script
# source. npx/skills would otherwise drain it, swallowing every line below.
npx -y skills add "${REPO}" --skill "${SKILL}" -a universal -y </dev/null

[ -f "${CANONICAL}/SKILL.md" ] || fail "skills CLI did not produce ${CANONICAL}/SKILL.md"

# --- reconcile the .claude/skills/memex symlink ------------------------------
mkdir -p ".claude/skills"
if [ -L "${LINK}" ]; then
  rm -f "${LINK}"
elif [ -e "${LINK}" ]; then
  fail "${LINK} exists and is not a symlink. Remove it and re-run."
fi
ln -s "../../.agents/skills/${SKILL}" "${LINK}"

# --- verify the guaranteed structure -----------------------------------------
[ -L "${LINK}" ]                || fail "${LINK} is not a symlink"
[ -f "${LINK}/SKILL.md" ]       || fail "${LINK} does not resolve to the skill"
[ -f "skills-lock.json" ]       || fail "skills-lock.json was not created"

say ""
say "memex installed:"
say "  ${CANONICAL}/"
say "  ${LINK} -> ../../.agents/skills/${SKILL}"
say "  skills-lock.json"
say ""
say "Next: point an agent at this repo —"
say '  "Audit the memex in this repo and scaffold whatever is missing."'
