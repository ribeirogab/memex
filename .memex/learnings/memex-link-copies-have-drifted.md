---
tags:
  - learning
  - gotcha
related:
  - "[[companion-skill-distribution-topology]]"
  - "[[../specs/2026-06-14-rename-vault-to-memex/spec]]"
created: 2026-06-14
---
# The three `memex-link` copies are NOT byte-identical — capture a baseline diff before sweeping

The `memex-link` companion ships in three copies (`.agents/skills/memex-link/`, `plugins/memex/skills/link/`, `skills/memex/scaffold/skills/memex-link/`), and they have **silently drifted** — they are not byte-equivalent. Do not assume `diff -r` between them returns empty, and do not write an acceptance criterion that asserts it. Capture the actual baseline `diff -rq` *before* a cross-copy sweep, and verify the sweep introduces **no new** divergence rather than verifying equivalence.

## Context

While renaming `.vault/` → `.memex/` (`[[../specs/2026-06-14-rename-vault-to-memex/spec]]`), the spec initially copied the predecessor's "`diff -r` returns empty" acceptance criterion. Running it at baseline disproved it:

- **Plugin copy fixtures kept the pre-bare-filenames naming.** `.agents/.../fixtures/.vault/specs/2026-01-01-test-spec/` has bare `spec.md`/`plan.md`/`tasks.md`; the plugin copy still has `spec-test-spec.md`/`plan-test-spec.md`/`tasks-test-spec.md`. The bare-filenames migration never reached the plugin fixtures.
- **The scaffold copy's bundled test is pre-existingly broken.** Its fixture directory is `vault` (no leading dot) while `find-candidates.sh` checks `[ -d .vault ]` and walks `.vault/...`, so `tests/run.sh` prints `FATAL: .vault/ not found` and never reaches a PASS/FAIL diff. Only the `.agents` and `plugins/link` copies' tests actually run green. (The no-dot fixture is likely a packaging workaround — a literal `.memex`/`.vault` dir inside `scaffold/` risks being treated as hidden/ignored when copied into a target repo — but whatever the reason, the as-shipped scaffold test does not execute.)

Both are out of scope for a rename, but they invalidate any "copies are identical" assumption.

## How to Apply

- **Before** any sweep that edits all three copies, run and save `diff -rq` between them. Treat that as the baseline.
- Verify the change introduces no *new* divergence: normalize the renamed token out of both baseline and post-change `diff -rq` output (anchor the normalization on the path component you renamed, e.g. `fixtures/\.?vault` → `fixtures/DIR`, so unrelated path components like `memex-link` are untouched) and confirm the lists match.
- Only assert tests PASS for the `.agents` and `plugins/link` copies. The scaffold copy's test is pre-broken; assert its behavior is *unchanged*, not that it passes.
- Consider fixing the two drifts as their own scoped tasks: migrate the plugin fixtures to bare filenames, and reconcile the scaffold fixture dirname with what `find-candidates.sh` expects. See [[companion-skill-distribution-topology]].
