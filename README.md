# Neovim config: a review window for Claude Code

LazyVim with a small set of modules (`lua/cc/`) for reviewing what Claude Code changes in a
multi-worktree repository. Neovim runs next to the agent and shows its work; it is not where
the code gets written.

Requirements: Neovim 0.11 or newer (developed on 0.12), `git`, and `uv` on `PATH` (Python
environments are created with it).

## Worktrees

The active worktree is derived from the directory Neovim starts in. At a project root that is not
itself a worktree (for example the parent of a bare repo) the statusline shows `⚠ no worktree`
until you pick one.

- `<leader>gw`: pick a worktree. The active one is marked `●`.
- Switching is refused while any buffer from another worktree of the project has unsaved changes.
  Otherwise it closes any diffview, deletes every buffer belonging to a worktree other than the
  target (loaded or just listed), and `:cd`s into the new one. Files outside the project's
  worktrees are left open.
- File and grep pickers skip worktrees nested inside the active one.

## Review

Diffview against the merge-base of `HEAD` with `origin/main` (or `main` if there is no remote).
Press `<leader>ghs` (gitsigns) in the right pane to stage hunks.

| Key | Action |
| --- | --- |
| `<leader>gvv` | Branch diff against the base |
| `<leader>gvc` | Branch commits, one at a time |
| `<leader>gvb` | Pick a different base ref (remembered per worktree for the session) |
| `<leader>gvm` | Toggle the current file reviewed, then go to the next file |
| `<leader>gvp` | Review progress picker |
| `<leader>gvq` | Close the review |

## Reviewed marks

`m` in the diffview file panel, or `<leader>gvm` anywhere (including the diff panes, where `m`
stays Vim's mark command), marks the file under the cursor as reviewed. A mark stores the file's
content hash, so editing the file afterwards makes it stale (`~`). The progress picker
(`<leader>gvp`) lists changed and untracked files as `✓` reviewed, `~` stale, `·` todo, with a
count in the title; selecting one opens it. Marks are kept per worktree and branch in
`stdpath("state")/cc-review-marks.json`.

## Disk sync

Files are checked against disk on focus, buffer enter and cursor hold. An unmodified buffer
reloads silently. A modified buffer is kept and a warning is shown, since the file changed
underneath your edits. `:CcDiffDisk` opens a diff of the current buffer against the file on disk.

## Python environments

Each package with a `pyproject.toml` uses its own `.venv`. `ty` and `ruff` run from that venv, not
from Mason or `PATH`; pyright and venv-selector are disabled. When you open a Python file and the
package has no `.venv`, `uv sync --frozen --all-groups --all-extras` runs once in the package
root, with concurrent opens sharing one sync. A failed sync is not retried automatically.
Formatting uses the ruff client. neotest runs pytest through `uv run --frozen --project <root>`
with the package root as the working directory. On a worktree switch, `ty` and `ruff` clients
rooted outside the new worktree are stopped.

- `:CcPyenvSync`: force a `uv sync` for the current buffer's package (also clears a failed state).
- `:CcPyenvInfo`: show the package root, venv, Python version, and the `ty` and `ruff` paths.

## Other languages

YAML, TOML, JSON and Markdown come from LazyVim extras (see `lazyvim.json`). YAML additionally
maps the [otter](https://github.com/opentargets/otter) config schema onto `**/pis/config.yaml`
and `**/pts/config.yaml`, alongside SchemaStore.

## Tests and maintenance

```sh
make test    # plenary specs in tests/cc, headless, minimal init
make smoke   # start the full config headless, fail on errors in :messages
```

`scripts/acceptance.lua` walks the whole workflow (worktree switch, branch diff, marks, commit
history, disk sync, refused switch, ty and ruff attach) against a real repository. It does not
modify tracked files; the Python step may create the package `.venv` and tool caches through the
normal environment sync. Run it from the project root:

```sh
cd ~/Projects/pipeline && nvim --headless -c "luafile ~/.config/nvim/scripts/acceptance.lua"
```

`scripts/lsp_check.lua` opens one Python file and prints which `ty` and `ruff` binaries attached:
`nvim --headless -c "luafile scripts/lsp_check.lua" path/to/file.py`.
