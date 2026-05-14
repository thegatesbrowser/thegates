---
tags: [git, workflow, submodule]
---

# Submodule Workflow

`godot/` is a git submodule — a separate repository (`thegatesbrowser/godot`) checked out inside the parent. This note covers the branch landscape, the cross-repo commit pattern, and the gotchas that don't show up until you hit them.

## Branch landscape

Inside the submodule (`godot/`):

| Branch | What it is |
|--------|------------|
| `tg-master` | Default branch on origin. The integration branch tracking upstream Godot's stable, with TheGates' patches on top. |
| `tg-4.5` | Active dev branch for the current Godot 4.5-based renderer. **Current branch as of writing.** |
| `tg-4.3` | Older Godot 4.3-based work (kept for reference). |
| `tg-4.2` | Older Godot 4.2-based work (kept for reference). |
| `chromium-sandboxing` / `chromium-sandboxing-4.3-old` | Ongoing sandboxing experiments (in-progress per the security model docs). |

`.gitmodules` pins `branch = tg-4.2`. This is stale — it predates the 4.3 → 4.5 upgrades and hasn't been bumped. The actual checkout floats on whatever the parent's submodule pointer says, which is currently a commit on `tg-4.5`. You can ignore the `.gitmodules` branch line until / unless someone wants to clean it up.

`origin/HEAD` on the submodule points to `tg-master`. A fresh `git submodule update --init` checks out the commit the parent points to (detached HEAD), not `tg-master` — that's normal submodule behavior.

### The tg-4.5 / tg-master sync rule

**Every commit pushed to `tg-4.5` must also be cherry-picked to `tg-master` and pushed.** `tg-master` is the integration branch and has to include everything `tg-4.5` does. The two branches diverge in SHA (because `tg-master` is independently rebased on upstream Godot), but their content stays equivalent.

```bash
# inside godot/, after work lands on tg-4.5:
git push origin tg-4.5
git checkout tg-master
git cherry-pick <sha>           # or <sha1>^..<shaN> for a range
git push origin tg-master
git checkout tg-4.5
```

Cherry-pick mechanically with `git commit -C <sha>` if you want to keep the original message verbatim after a `-n` cherry-pick. Don't try to rewrite commit messages to match SHAs across branches — the original SHA in a message body (e.g. "Added in commit `170ccff0a9`") will dangle on the other branch, which is acceptable; the equivalent commit on the other branch shares the same commit-message text and can be found by `git log --grep`.

In the parent (`thegates/`):

The parent has a single working branch (`main`). The submodule pointer (`git ls-tree HEAD godot`) records the godot commit that goes with each parent commit.

## The cross-repo commit pattern

When a change touches both repos (e.g. adding fork docs in the submodule and updating parent CLAUDE.md), the workflow is two separate commits:

1. **Commit inside the submodule first.** `cd godot && git add ... && git commit`. This commit lives in the godot fork's history.
2. **Commit in the parent.** From the parent root, stage the parent-side files normally — and *separately* decide whether to bump the submodule pointer.

The submodule-pointer bump shows up in `git status` as `modified: godot (new commits)`. Two ways to handle it:

- **Bump now:** include `godot` in `git add` for the parent commit. The parent commit then locks in the new submodule SHA. Use this when the parent-side changes depend on the submodule changes (e.g. CI workflows that reference new files inside the submodule).
- **Defer the bump:** leave `godot (new commits)` out of staging. The parent commit changes only parent-side files; the submodule SHA stays where it was. Use this when the submodule changes are independent and can land in a separate parent commit (often part of the user's ship process).

The docs reorg on 2026-05-14 used the deferred pattern: the parent commit updated `CLAUDE.md` + `docs/Index.md` + removed the moved notes, but did NOT bump the submodule pointer.

## Gotchas

### `git mv` doesn't work across the submodule boundary

The two repos have separate `.git` directories. Moving a file from `thegates/docs/foo.md` to `godot/notes/foo.md` cannot be done as a single `git mv` — git sees one repo at a time. The actual workflow is a plain filesystem `mv`, then each repo stages its own half: parent stages the deletion, submodule stages the addition. History won't link across — the file appears as "added" in the godot fork starting from the move commit.

### Pre-commit hooks run on the submodule side only

`godot/.pre-commit-config.yaml` is the godot fork's pre-commit config (clang-format, clang-tidy, codespell, ruff). It triggers when you commit *inside* `godot/`. The parent repo has no pre-commit hooks by default — parent commits are unguarded. If you stage C++ files in the parent (unusual, but possible if something gets misrouted), no hooks check them.

### Submodule "new commits" warning sticks around until pointer bump

After committing inside the submodule, the parent's `git status` shows `modified: godot (new commits)` indefinitely. That's not a dirty-state warning to clean up — it's git telling you the parent's submodule pointer is behind the actual checkout. The warning clears when the parent commits the new pointer (or resets the submodule).

### Cloning standalone vs. cloning with submodule

`git clone https://github.com/thegatesbrowser/thegates.git` (parent) leaves `godot/` empty. You need `git submodule update --init --recursive` (or `--recurse-submodules` on the clone command) to populate it. Anyone cloning the godot fork directly (`git clone .../godot.git`) gets the submodule's contents at whatever branch they ask for — they don't get the parent. This is why fork-specific docs live in `godot/notes/`: they travel with whichever clone direction someone takes.

### Detached HEAD after `submodule update`

A fresh `git submodule update` checks out the commit the parent points to, not a named branch. To start working: `cd godot && git checkout tg-4.5` (or whatever branch you want). Committing on a detached HEAD silently dangles the commit until you `git checkout -b ...`.

## When in doubt

Read [git submodule's official docs](https://git-scm.com/book/en/v2/Git-Tools-Submodules) — they cover the abstract model well. The notes above only catch project-specific traps.
