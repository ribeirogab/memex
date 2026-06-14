---
tags:
  - learning
  - gotcha
related:
  - "[[../specs/2026-06-14-rename-vault-to-memex/spec]]"
  - "[[rename-spec-grep-first]]"
  - "[[sed-rename-pattern-completeness]]"
created: 2026-06-14
---
# Renaming toward an overloaded token — verify on the OLD token, never the new one

When a rename's **target** token already appears legitimately all over the repo (e.g. renaming the vault dir `.vault/` → `.memex/`, where `memex` is the product name and shows up in `plugins/memex/`, `skills/memex/`, prose, commits), you **cannot** verify success by asserting "zero stray occurrences of the new token" — the new token is supposed to be everywhere. Anchor every grep and every acceptance criterion on the **old** token instead, and frame completeness as "the old token survives only in the places we deliberately froze."

## Context

The `context/` → `.vault/` rename (`[[../specs/2026-05-03-rename-context-to-vault/spec]]`) went from one distinctive token to another, so its acceptance criteria could say "`git grep context/` returns nothing outside frozen specs." The `.vault/` → `.memex/` rename inverted that property: the destination `memex` is the most common word in the repo. An AC like "no stray `memex`" would match thousands of legitimate lines and verify nothing.

Two further traps specific to this shape:
- The **bare conceptual word** stayed in scope-out. We kept *vault* as the knowledge-management term ("the knowledge vault", `vault-files.md`, spec folders like `rename-context-to-vault`). So even greping the *old* word bare (`vault`) floods with false positives. Only the **dot-path token** `\.vault` is unambiguously the directory.
- A file partitioned across task lists by category fell through the gap: the rename split files into "non-link companions" (one task) and "link scripts/fixtures" (another), and `memex-link/SKILL.md` belonged to neither. The final repo-wide `git grep '\.vault'` sweep caught it — proving the sweep is non-optional even after per-task verification.

## How to Apply

For a rename whose target token is non-distinctive (product name, common English word):

1. **Anchor on the old token in its most disambiguating form.** Here that was `\.vault` (leading dot) — the directory always carries the dot; the concept never does. Use `git grep -n '\.vault'`, never `grep -w vault` or `grep memex`.
2. **Write the completeness AC as a filtered old-token grep:** `git grep -l '\.vault' | grep -v '^\.memex/specs/'` must return only the deliberately-frozen survivors (frozen specs + any annotated historical-narrative learning). This is verifiable in seconds and immune to the new token's ubiquity.
3. **Replace with the disambiguating pattern too:** `perl -pi -e 's/\.vault/.memex/g'` — the literal `\.` keeps the conceptual bare word untouched.
4. **Always run a final repo-wide old-token sweep** after the per-task flips, even if each task self-verified. Category-partitioned task lists leak edge files; the sweep is the backstop ([[rename-spec-grep-first]]).
