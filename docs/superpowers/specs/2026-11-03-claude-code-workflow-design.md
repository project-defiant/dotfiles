# Neovim as the review window for Claude Code — design

Date: 2026-11-03
Config: `~/.config/nvim` (LazyVim starter, no customisations yet)
Reference project: `~/Projects/pipeline`

## Intent

Claude Code runs in its own terminal window and writes code inside git worktrees. Neovim runs in a
**separate window** and is where the user **reviews and redacts** what Claude produced, and moves between
worktrees. Neovim is the human's side of the loop; it is not another AI front-end.

## Context: how the pipeline repo is laid out

- **Bare-repo worktree layout.** `~/Projects/pipeline/.git` contains `gitdir: ./.bare`; the bare repo is
  `.bare/`. ~30 worktrees sit beside it, at paths named after their branch: `main/`, `feat/<name>/`,
  `fix/<name>/`, `chore/<name>/`, … (one is even nested: `main/feat/pts-credible-set-schema-migration`).
- **Each worktree is a monorepo of four uv packages:** `pis`, `pts`, `orchestration`, `croissant`. Each has
  its own `pyproject.toml`, `uv.lock`, `.python-version` (`pis` = 3.11, others = 3.12) and its own `.venv`
  (`<worktree>/<package>/.venv`).
- **Team tooling is ruff + ty (Astral).** `ruff.toml` at the worktree root, packages `extend = "../ruff.toml"`.
  Both are pinned per package in dev deps: `ruff==0.16.10`, `ty==0.0.85`. The VS Code workspace disables
  Pylance (`python.languageServer: None`) and uses ty + ruff. Neither tool is installed globally.
- Other file types in play: YAML (`pis/config.yaml`, `pts/config.yaml` validated against the otter schema
  `https://raw.githubusercontent.com/opentargets/otter/refs/heads/main/.vscode/config-schema.json`),
  TOML, JSON / JSON-LD, Makefiles, Markdown.

## Goals

1. **Review of Claude's work: branch diff, commits, redaction.**
   - Claude commits as it works, so review is built around commits, not the index.
   - **Branch diff:** the full diff of the active worktree's branch against its base, with a file list and
     side-by-side diff per file. Default base = merge-base with `origin/main`; a picker overrides the base
     for stacked branches (e.g. `feat/pts-*` on `chore/pts-migration-base`).
   - **Commit view:** the list of the branch's own commits (base..HEAD); selecting a commit opens its diff
     with the same file list / side-by-side layout, so the user can walk Claude's work step by step.
   - **Redaction:** the right-hand side of the branch diff is the real working-tree file; the user edits it
     in place and the diff refreshes. Redactions become new uncommitted changes on top of Claude's commits.
   - **Staging applies to uncommitted work only** (Claude's in-progress edits and the user's redactions):
     stage / unstage / reset hunks and whole files from the diff view and from ordinary buffers.
   - Per-file "reviewed" marks in the branch diff track progress through a large branch.
2. **Worktree jumping inside one Neovim session.**
   - User starts `nvim` once in `~/Projects/pipeline` (the bare root).
   - A picker lists worktrees (from `git worktree list`, so new ones appear without restarting) by branch
     name. Selecting one makes it the **active worktree**.
   - **One worktree at a time:** switching closes the previous worktree's buffers and diff view and changes
     the working directory to the new worktree, so file finder, grep, git status and the review diff are all
     scoped to it.
   - **Always-visible pointer:** the status line shows the active worktree's branch name.
3. **Python that resolves the right environment automatically.**
   - Language servers: **ty** (types / navigation) and **ruff** (lint, format, organise imports), matching
     the team's VS Code setup. No pyright/basedpyright.
   - The project root for a Python file is the nearest package dir (`pyproject.toml`), found from the file's
     own path — independent of where Neovim was started. The environment is that package's `.venv`, so a
     file in `feat/pis-foldx/pis/` gets `feat/pis-foldx/pis/.venv` (3.11) and one in `main/pts/` gets
     `main/pts/.venv` (3.12).
   - Use the **pinned tool binaries** from the package `.venv` (`.venv/bin/ty`, `.venv/bin/ruff`) so
     diagnostics match `make lint`.
   - **Missing `.venv` → auto `uv sync`.** The first time a file in a package without a `.venv` is opened,
     Neovim runs `uv sync` in that package (async, with a progress notification), then starts the language
     servers against the new venv. Failures are reported, not swallowed. At most one sync per package runs
     at a time.
   - Format on save with ruff (respects `ruff.toml`, e.g. single quotes, 120 cols).
   - Run the nearest test / file tests via pytest through `uv run` in the package dir.
4. **Live reload of Claude's edits.** Unmodified buffers reload silently when Claude changes the file on
   disk (checked on focus, buffer enter and cursor idle). A **modified** buffer keeps the user's edits and
   shows a warning; a command diffs the buffer against the on-disk version. Format-on-save must not
   overwrite a newer on-disk version silently.
5. **Supporting languages** via LazyVim extras: Python, YAML (with the otter schema mapped to
   `*/pis/config.yaml`, `*/pts/config.yaml`), TOML, JSON, Markdown, Makefile-friendly basics.

## Non-goals

- Creating or removing worktrees from Neovim (done in the terminal by the user or Claude).
- Multiple worktrees open at once / tab-per-worktree.
- Debugger (DAP) setup.
- Generalising beyond the pipeline layout beyond what falls out naturally (other repos should still work
  as ordinary single-checkout repos).

## Anti-goals

- **No AI / Claude plugin inside Neovim** (no claudecode.nvim, avante, copilot chat, etc.). Claude stays in
  its own window.
- Editing the wrong worktree by accident — the pointer and the "one at a time" rule exist to prevent it.
- Type/lint results that disagree with the repo's pinned tool versions.
- Breaking the plain LazyVim experience: customisations live in `lua/plugins/*.lua` and
  `lua/config/*.lua`, following LazyVim conventions, not by forking defaults.

## Constraints

- **Neovim must be upgraded first.** Installed: 0.10.4 (Homebrew). Homebrew stable: 0.12.x. Current
  LazyVim and the `vim.lsp.config`-style server setup (used for ty) need ≥ 0.11. Upgrade, then
  `:Lazy update`, then add customisations.
- macOS, zsh, Homebrew; `uv` is installed globally.
- LazyVim's picker is snacks.nvim (already installed); the worktree picker should use it rather than add
  telescope/fzf-lua.
- Keep `lazy-lock.json` committed so a working plugin set can be restored.

## Decided by the user

- Neovim is a separate review window, not embedded with Claude.
- Review = full branch diff plus commit-by-commit view, with the ability to redact (edit) changes; staging
  for uncommitted work.
- Diff base = merge-base with `origin/main`, overridable for stacked branches.
- Missing package `.venv` → Neovim runs `uv sync` automatically.
- File changed on disk while buffer modified → keep the user's edits and warn.
- Open the whole project root and jump between worktrees inside Neovim.
- One worktree at a time; previous one goes away on switch.
- Status line pointer to the active worktree.
- Python must handle multiple environments as in the pipeline repo.

## Calls made by Claude (open to correction)

- ty + ruff as the Python LSP stack, using venv-pinned binaries.
- Interpreted "then view commits" as a commit-by-commit review view alongside the branch diff.
- diffview.nvim for branch diff + in-place editing; gitsigns (already present) for hunk staging.
- Auto-reload of files changed on disk.
- Pytest runner via neotest (LazyVim test extra) with `uv run`.
- Extras for YAML/TOML/JSON/Markdown; otter schema mapping for pis/pts config.
- No debugger; no worktree create/delete.

## Left to the builder

- Exact keymaps (stay within LazyVim's `<leader>g…` git group and `<leader>t…` test group; document them
  in which-key descriptions).
- How the worktree picker and pointer are implemented (custom snacks picker source vs. a small plugin), as
  long as behaviour above holds — including the nested worktree path case and the bare root itself not
  being offered as a worktree.
- Precise mechanism for per-file root + venv-binary resolution in the LSP configs.
- How "close previous worktree" handles modified, unsaved buffers (must not silently discard edits).
- Branch names that differ from their directory path (e.g. dir `feat/credible-set-refactor`, branch
  `credible-set-refactor`): show both in the picker.
- Whether finder/grep in `main` hide the nested `main/feat/...` worktree (they should not show its files as
  part of `main`).
- What is active at startup in the bare root before a worktree is picked.
