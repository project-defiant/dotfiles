# Neovim Review Window for Claude Code Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the stock LazyVim config into a review window for Claude Code: jump between worktrees of a bare-repo project, review a branch (diff + commits), redact in place, and get per-package Python tooling (ty + ruff from each package's `.venv`, auto `uv sync`).

**Architecture:** Behaviour lives in small Lua modules under `lua/cc/` (no plugin dependencies in their core logic, so they are unit-testable headless). Thin LazyVim plugin specs in `lua/plugins/` wire them to snacks.nvim (pickers), diffview.nvim (review), lualine (pointer), nvim-lspconfig (ty/ruff) and neotest. Modules talk through one `User CcWorktreeChanged` autocmd.

**Tech Stack:** Neovim ≥ 0.11 (target Homebrew 0.12.x), LazyVim, snacks.nvim, diffview.nvim (`sindrets/diffview.nvim`), gitsigns, lualine, nvim-lspconfig (`vim.lsp.config` API), neotest + neotest-python, plenary.nvim busted for tests, git, uv.

**Spec:** `docs/superpowers/specs/2026-11-03-claude-code-workflow-design.md` (wiki PRD: `Projects/nvim-claude-code-review/PRD/2026-11-03-neovim-review-window.md` in vault `v`).

## Global Constraints

- Neovim ≥ 0.11 required; upgrade before any `:Lazy update`.
- No AI/Claude plugin inside Neovim.
- Python LSP stack is ty + ruff only; pyright and basedpyright disabled; no `venv-selector.nvim`.
- ty/ruff binaries come from `<package>/.venv/bin/` (pinned `ruff==0.16.10`, `ty==0.0.85` in the pipeline repo); Mason must not install or supply them.
- Auto sync command: `uv sync --frozen --all-groups --all-extras` run in the package root (same as the pipeline repo's `make dev-%`). Never modify `uv.lock`.
- Diff base default: `git merge-base origin/main HEAD`.
- One active worktree at a time; never silently discard unsaved edits.
- Customisations only in `lua/plugins/*.lua`, `lua/config/*.lua`, `lua/cc/*.lua`; keymaps under `<leader>gw` (worktrees), `<leader>gv…` (review), `<leader>t…` (tests, LazyVim default) with which-key `desc`.
- `lazy-lock.json` committed.
- otter schema URL: `https://raw.githubusercontent.com/opentargets/otter/refs/heads/main/.vscode/config-schema.json` for `**/pis/config.yaml`, `**/pts/config.yaml`.

## Review Focus

1. **No `origin/main` (no remote, or not fetched)** → base falls back to `git merge-base main HEAD`; if neither exists, a clear error, not a diffview crash. Test in Task 5.
2. **`uv sync` fails (offline, broken lock)** → one error notification per package, no re-run on every buffer open until `:CcPyenvSync`. Test in Task 7.
3. **`.venv` exists but lacks `ty`/`ruff`** (synced without dev group) → warn once per package, that server is not started, no crash. Test in Task 7.
4. **Detached-HEAD or prunable (folder deleted) worktree** → picker shows `(detached)`, prunable entries excluded. Test in Task 2.
5. **Claude deletes a file open in a buffer** → buffer kept as-is with a warning, never wiped or reloaded into an error. Test in Task 4.

---

## File Structure

| File | Responsibility |
|---|---|
| `lua/cc/worktree.lua` | Parse `git worktree list --porcelain`, track active worktree, switch safely, emit `User CcWorktreeChanged` |
| `lua/cc/review.lua` | Resolve diff base (default/override), open branch diff & commit history via diffview, pick base |
| `lua/cc/marks.lua` | Per-file "reviewed" marks keyed by worktree+branch, content-hash based, persisted in `stdpath("state")` |
| `lua/cc/pyenv.lua` | Package root / venv / tool resolution, single-flight `uv sync` |
| `lua/cc/disksync.lua` | Reload-on-change policy, conflict warnings, `:CcDiffDisk` |
| `lua/plugins/worktree.lua` | snacks picker source, `<leader>gw`, lualine pointer, nested-worktree excludes for files/grep |
| `lua/plugins/review.lua` | diffview spec, `<leader>gv…` keymaps, progress picker |
| `lua/plugins/python.lua` | ty/ruff server config, disable pyright/basedpyright/venv-selector, conform, neotest-python |
| `lua/plugins/langs.lua` | yamlls otter schema mapping |
| `lua/config/options.lua`, `lua/config/autocmds.lua` | Globals for the python extra; `require("cc.disksync").setup()`, `require("cc.worktree").setup()` |
| `lazyvim.json` | Extras list |
| `tests/minimal_init.lua`, `tests/helpers.lua`, `tests/cc/*_spec.lua` | Headless plenary-busted tests and git/venv fixtures |
| `Makefile`, `scripts/smoke.sh` | `make test`, `make smoke` |

Removed: `lua/plugins/example.lua`, `.neoconf.json`. `README.md` rewritten in Task 10.

---

### Task 1: Baseline, Neovim upgrade, test harness

**Files:**
- Delete: `lua/plugins/example.lua`, `.neoconf.json`
- Create: `tests/minimal_init.lua`, `tests/helpers.lua`, `tests/cc/harness_spec.lua`, `Makefile`, `scripts/smoke.sh`
- Modify: `lazy-lock.json` (via `:Lazy update`)

**Interfaces:**
- Produces:
  - `tests/minimal_init.lua`: prepends the config dir and `stdpath("data")/lazy/plenary.nvim` to `runtimepath`; loads nothing else.
  - `helpers.tmpdir() -> string` (removed after the test via `after_each(helpers.cleanup)`).
  - `helpers.git(dir: string, args: string[]) -> string` (runs `git -C dir …`, errors on non-zero, returns trimmed stdout).
  - `helpers.bare_project(opts?: { main?: string }) -> { root: string, wt: table<string,string> }` — `opts.main` defaults to `"main"` and names the trunk branch/folder below. Creates `<root>/.bare` (bare repo, initial commit on `main` with `pis/pyproject.toml`, `pts/pyproject.toml`), `<root>/.git` file containing `gitdir: ./.bare`, and worktrees `main` → `<root>/main`, `feat/a` → `<root>/feat/a`, branch `credible` at folder `<root>/feat/credible`, and nested `feat/nested` → `<root>/main/feat/nested`. Keys of `wt` are branch names.
  - `make test` → `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/cc {minimal_init='tests/minimal_init.lua', sequential=true}"`.
  - `make smoke` → `scripts/smoke.sh`: starts the full config headless, waits 3 s, writes `:messages`, exits 1 if any line matches `E%d+:` or `Error`/`WARN`.

- [ ] **Step 1: Commit the untouched starter as baseline**

```bash
git add -A && git commit -m "chore: LazyVim starter baseline"
```

- [ ] **Step 2: Upgrade Neovim**

Run: `brew upgrade neovim && nvim --version | head -1`
Expected: `NVIM v0.12.x` (any ≥ 0.11.2).

- [ ] **Step 3: Update plugins, delete template leftovers**

Delete `lua/plugins/example.lua` and `.neoconf.json`. Run: `nvim --headless "+Lazy! sync" +qa`. Then confirm `lazy-lock.json` changed (`git diff --stat lazy-lock.json`).

- [ ] **Step 4: Write `scripts/smoke.sh`, `Makefile`, test helpers and a harness test**

`tests/cc/harness_spec.lua`:

```lua
local h = require("tests.helpers")
describe("fixtures", function()
  after_each(h.cleanup)
  it("builds a bare project with worktrees", function()
    local p = h.bare_project()
    assert.equals("main", h.git(p.wt["main"], { "branch", "--show-current" }))
    assert.equals("credible", h.git(p.root .. "/feat/credible", { "branch", "--show-current" }))
    assert.is_truthy(vim.uv.fs_stat(p.root .. "/main/feat/nested/.git"))
  end)
end)
```

- [ ] **Step 5: Run smoke and tests**

Run: `make smoke && make test`
Expected: smoke exits 0; `Success: 1 Failed : 0 Errors : 0`.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "chore: upgrade plugins for nvim 0.12, add test harness and smoke check"
```

---

### Task 2: Worktree manager

**Files:**
- Create: `lua/cc/worktree.lua`, `tests/cc/worktree_spec.lua`
- Modify: `lua/config/autocmds.lua` (call `require("cc.worktree").setup()`)

**Interfaces:**
- Consumes: Task 1 helpers.
- Produces (`require("cc.worktree")`):
  - type `Worktree = { path: string, branch: string|nil, head: string, detached: boolean }` (`branch` is the short name, e.g. `feat/a`; `nil` when detached).
  - `list(dir?: string) -> Worktree[]` — from `git -C (dir or cwd) worktree list --porcelain`; excludes `bare` and `prunable` entries; sorted by `branch or path`.
  - `owner(path: string, wts?: Worktree[]) -> Worktree|nil` — worktree whose `path` is the longest prefix of `path` (on path-separator boundaries).
  - `active() -> Worktree|nil`.
  - `nested(wt: Worktree, wts?: Worktree[]) -> string[]` — paths of other worktrees under `wt.path`, relative to it (e.g. `{"feat/nested"}`).
  - `switch(path: string) -> boolean, string|nil` — if any listed, modified buffer is owned by the current active worktree, returns `false, "unsaved: <names>"` and changes nothing. Otherwise: closes diffview tabs (`pcall(vim.cmd, "DiffviewClose")` per diffview tab), wipes buffers owned by the old worktree, `vim.cmd.cd(path)`, sets active, fires `User CcWorktreeChanged` with `data = Worktree`. Returns `true`.
  - `setup()` — on startup sets active to `owner(cwd)` (nil at the bare root, which is not a worktree).

- [ ] **Step 1: Write failing tests** (`tests/cc/worktree_spec.lua`)

```lua
local h, wt = require("tests.helpers"), require("cc.worktree")
describe("cc.worktree", function()
  local p
  before_each(function() p = h.bare_project() end)
  after_each(h.cleanup)

  it("lists checkouts, not the bare repo", function()
    local names = vim.tbl_map(function(w) return w.branch end, wt.list(p.root))
    assert.same({ "credible", "feat/a", "feat/nested", "main" }, names)
  end)
  it("marks detached worktrees and drops prunable ones", function()
    h.git(p.root, { "worktree", "add", "--detach", p.root .. "/run/x" })
    vim.fn.delete(p.wt["feat/a"], "rf") -- now prunable
    local l = wt.list(p.root)
    local x = vim.tbl_filter(function(w) return w.path == p.root .. "/run/x" end, l)[1]
    assert.is_true(x.detached); assert.is_nil(x.branch)
    assert.is_nil(vim.tbl_filter(function(w) return w.branch == "feat/a" end, l)[1])
  end)
  it("resolves owner by longest prefix", function()
    local l = wt.list(p.root)
    assert.equals("feat/nested", wt.owner(p.root .. "/main/feat/nested/pis/x.py", l).branch)
    assert.equals("main", wt.owner(p.root .. "/main/pis/x.py", l).branch)
    assert.is_nil(wt.owner(p.root .. "/.bare/HEAD", l))
  end)
  it("reports nested worktrees", function()
    local l = wt.list(p.root)
    assert.same({ "feat/nested" }, wt.nested(wt.owner(p.wt["main"], l), l))
  end)
  it("switches cwd, wipes old buffers, fires event", function()
    vim.cmd.cd(p.root); wt.setup(); assert.is_nil(wt.active())
    assert.is_true(wt.switch(p.wt["main"]))
    vim.cmd.edit(p.wt["main"] .. "/pis/pyproject.toml")
    local fired; vim.api.nvim_create_autocmd("User", { pattern = "CcWorktreeChanged", once = true,
      callback = function(e) fired = e.data.branch end })
    assert.is_true(wt.switch(p.wt["feat/a"]))
    assert.equals(p.wt["feat/a"], vim.fn.getcwd())
    assert.equals("feat/a", fired)
    assert.equals(-1, vim.fn.bufnr(p.wt["main"] .. "/pis/pyproject.toml"))
  end)
  it("refuses to switch with unsaved buffers", function()
    wt.switch(p.wt["main"]); vim.cmd.edit(p.wt["main"] .. "/pis/pyproject.toml")
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { "# edit" })
    local ok, err = wt.switch(p.wt["feat/a"])
    assert.is_false(ok); assert.matches("unsaved", err)
    assert.equals(p.wt["main"], vim.fn.getcwd())
    vim.cmd("bwipeout!")
  end)
end)
```

- [ ] **Step 2: Run, expect failure**

Run: `make test` — Expected: FAIL, `module 'cc.worktree' not found`.

- [ ] **Step 3: Implement `lua/cc/worktree.lua`** per Interfaces. Normalise all paths with `vim.fs.normalize` + `vim.uv.fs_realpath` (macOS `/private/tmp` vs `/tmp`). Wire `setup()` in `lua/config/autocmds.lua`.

- [ ] **Step 4: Run, expect pass**

Run: `make test` — Expected: `Failed : 0 Errors : 0`.

- [ ] **Step 5: Commit**

```bash
git add lua/cc/worktree.lua tests/cc/worktree_spec.lua lua/config/autocmds.lua
git commit -m "feat: worktree manager with safe switching"
```

---

### Task 3: Worktree picker, status-line pointer, nested excludes

**Files:**
- Create: `lua/plugins/worktree.lua`
- Test: `tests/cc/worktree_spec.lua` (add `label` test)

**Interfaces:**
- Consumes: `cc.worktree.list/active/switch/nested`.
- Produces:
  - `cc.worktree.label(w: Worktree) -> string` — `branch`, plus `"  (<path relative to project root>)"` when the relative path differs from the branch; `"(detached) <path>"` when detached.
  - `<leader>gw` "Worktrees": `Snacks.picker` with items from `list()`, text = `label(w)`, current active marked; confirm → `switch(w.path)`; on `false` → `vim.notify(err, WARN)`.
  - lualine component inserted first in `lualine_b`: `" " .. active().branch` (or `"(detached)"`), `"⚠ no worktree"` when `active()` is nil; colour warning-hl when nil. Refresh on `User CcWorktreeChanged`.
  - snacks picker `sources.files.config` and `sources.grep.config` hooks that add `nested(active())` to `opts.exclude`.

- [ ] **Step 1: Write failing test for `label`**

```lua
it("labels worktrees whose folder differs from branch", function()
  local l = wt.list(p.root)
  local c = vim.tbl_filter(function(w) return w.branch == "credible" end, l)[1]
  assert.equals("credible  (feat/credible)", wt.label(c))
  assert.equals("main", wt.label(wt.owner(p.wt["main"], l)))
end)
```

- [ ] **Step 2: Run, expect failure** — `make test`, FAIL `attempt to call field 'label'`.
- [ ] **Step 3: Implement `label`** (project root = parent dir of the git common dir, from `git rev-parse --git-common-dir`), then the plugin spec in `lua/plugins/worktree.lua`.
- [ ] **Step 4: Run tests** — `make test`, all pass; `make smoke` exits 0.
- [ ] **Step 5: Manual check in `~/Projects/pipeline`**

`cd ~/Projects/pipeline && nvim` → status line shows `⚠ no worktree`; `<leader>gw` lists ~30 entries incl. `credible-set-refactor  (feat/credible-set-refactor)`; pick `main` → status line `  main`; `<leader>ff` shows no `feat/pts-credible-set-schema-migration/` files; `<leader>/` grep likewise.

- [ ] **Step 6: Commit**

```bash
git add lua/cc/worktree.lua lua/plugins/worktree.lua tests/cc/worktree_spec.lua
git commit -m "feat: worktree picker, status line pointer, nested worktree excludes"
```

---

### Task 4: Disk-sync guard

**Files:**
- Create: `lua/cc/disksync.lua`, `tests/cc/disksync_spec.lua`
- Modify: `lua/config/autocmds.lua`

**Interfaces:**
- Produces (`require("cc.disksync")`):
  - `setup()` — `vim.o.autoread = true`; `checktime` on `FocusGained`, `BufEnter`, `CursorHold`, `CursorHoldI` (skip when `vim.o.buftype ~= ""` or in cmdwin); `FileChangedShell` handler implementing `decide`.
  - `decide(bufnr: integer, reason: string) -> "reload"|""` — `"reload"` iff buffer unmodified and `reason ~= "deleted"`; otherwise `""` and `vim.b[bufnr].cc_disk_conflict = reason` plus one `vim.notify(..., WARN)` naming the file and `:CcDiffDisk`. Sets `vim.v.fcs_choice` when called from the autocmd.
  - `:CcDiffDisk` — opens a vertical split of the on-disk file (read-only scratch buffer) and `diffthis` on both.
  - Built-in "file changed since reading it" write prompt is left enabled (protects format-on-save + `:w`).

- [ ] **Step 1: Write failing tests**

```lua
local d = require("cc.disksync")
describe("cc.disksync.decide", function()
  local f, buf
  before_each(function()
    f = vim.fn.tempname() .. ".py"; vim.fn.writefile({ "a = 1" }, f)
    vim.cmd.edit(f); buf = vim.api.nvim_get_current_buf()
  end)
  after_each(function() vim.cmd("bwipeout!") end)

  it("reloads unmodified buffers", function()
    assert.equals("reload", d.decide(buf, "changed"))
  end)
  it("keeps modified buffers and flags conflict", function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a = 2" })
    assert.equals("", d.decide(buf, "changed"))
    assert.equals("changed", vim.b[buf].cc_disk_conflict)
  end)
  it("never reloads a deleted file", function()
    os.remove(f)
    assert.equals("", d.decide(buf, "deleted"))
    assert.equals("a = 1", vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
  end)
  it("end-to-end: checktime pulls in external change", function()
    d.setup(); vim.uv.sleep(1100) -- mtime resolution
    vim.fn.writefile({ "a = 3" }, f); vim.cmd.checktime()
    assert.equals("a = 3", vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
  end)
end)
```

- [ ] **Step 2: Run, expect failure** — `make test`, FAIL `module 'cc.disksync' not found`.
- [ ] **Step 3: Implement** per Interfaces; wire `setup()` in `lua/config/autocmds.lua`.
- [ ] **Step 4: Run, expect pass** — `make test`; `make smoke`.
- [ ] **Step 5: Commit**

```bash
git add lua/cc/disksync.lua tests/cc/disksync_spec.lua lua/config/autocmds.lua
git commit -m "feat: reload Claude's on-disk edits, keep unsaved user edits"
```

---

### Task 5: Review base and views

**Files:**
- Create: `lua/cc/review.lua`, `lua/plugins/review.lua`, `tests/cc/review_spec.lua`
- Modify: `tests/helpers.lua` (add `helpers.with_origin(p)`)

**Interfaces:**
- Consumes: `cc.worktree.active()`.
- Produces (`require("cc.review")`):
  - `base(wt_path: string) -> string|nil, string|nil` — returns `(sha, nil)` or `(nil, err)`. Order: session override for `wt_path` (`git merge-base <override> HEAD`), else `merge-base origin/main HEAD`, else `merge-base main HEAD`, else `nil, "no base: neither origin/main nor main found"`.
  - `set_override(wt_path: string, ref: string|nil)`.
  - `open_branch()` — `DiffviewOpen <sha>` (single rev ⇒ right side is the working tree, editable, includes uncommitted changes).
  - `open_commits()` — `DiffviewFileHistory --range=<sha>..HEAD`.
  - `pick_base()` — snacks picker over `git for-each-ref --format=%(refname:short) refs/heads refs/remotes`; confirm → `set_override`.
  - All three notify `"pick a worktree first"` when `active()` is nil and `err` when `base` fails.
  - `helpers.with_origin(p)` — creates bare remote, pushes `main`, adds 1 commit to remote main only, fetches, so local `main` is behind `origin/main`.
  - Keymaps (`lua/plugins/review.lua`, `sindrets/diffview.nvim`, `cmd = {"DiffviewOpen","DiffviewFileHistory","DiffviewClose"}`): `<leader>gv` group "review"; `<leader>gvv` branch diff, `<leader>gvc` commits, `<leader>gvb` pick base, `<leader>gvq` `DiffviewClose`. diffview `enhanced_diff_hl = true`, file panel listing style `tree`.

- [ ] **Step 1: Write failing tests**

```lua
local h, r = require("tests.helpers"), require("cc.review")
describe("cc.review.base", function()
  local p
  before_each(function() p = h.bare_project() end)
  after_each(h.cleanup)

  it("defaults to merge-base with origin/main", function()
    h.with_origin(p)
    local fa = p.wt["feat/a"]
    assert.equals(h.git(fa, { "merge-base", "origin/main", "HEAD" }), (r.base(fa)))
  end)
  it("falls back to local main without a remote", function()
    local fa = p.wt["feat/a"]
    assert.equals(h.git(fa, { "merge-base", "main", "HEAD" }), (r.base(fa)))
  end)
  it("honours a stacked-branch override", function()
    local fa = p.wt["feat/a"]
    h.git(fa, { "commit", "--allow-empty", "-m", "a1" })
    h.git(p.root, { "worktree", "add", "-b", "feat/b", p.root .. "/feat/b", "feat/a" })
    local fb = p.root .. "/feat/b"
    r.set_override(fb, "feat/a")
    assert.equals(h.git(fb, { "rev-parse", "feat/a" }), (r.base(fb)))
  end)
  it("errors clearly when no main exists", function()
    local q = h.bare_project({ main = "trunk" })
    local sha, err = r.base(q.wt["feat/a"])
    assert.is_nil(sha); assert.matches("no base", err)
  end)
end)
```

- [ ] **Step 2: Run, expect failure** — `make test`, FAIL `module 'cc.review' not found`.
- [ ] **Step 3: Implement `lua/cc/review.lua`, `helpers.with_origin`, and `lua/plugins/review.lua`.**
- [ ] **Step 4: Run tests and smoke** — `make test && make smoke`, both pass.
- [ ] **Step 5: Manual check** in `~/Projects/pipeline`: pick `feat/pis-foldx`, `<leader>gvv` shows its ~10 commits' files vs merge-base; edit right side, diff updates; `<leader>ghs` on a redacted hunk stages it (gitsigns); `<leader>gvc` lists the branch commits with messages; `<leader>gvq` closes.
- [ ] **Step 6: Commit**

```bash
git add lua/cc/review.lua lua/plugins/review.lua tests/cc/review_spec.lua tests/helpers.lua
git commit -m "feat: branch diff and commit review against origin/main merge-base"
```

---

### Task 6: Reviewed marks and progress

**Files:**
- Create: `lua/cc/marks.lua`, `tests/cc/marks_spec.lua`
- Modify: `lua/plugins/review.lua`

**Interfaces:**
- Consumes: `cc.review.base`, `cc.worktree.active`.
- Produces (`require("cc.marks")`):
  - `M.file = vim.fn.stdpath("state") .. "/cc-review-marks.json"` (overridable in tests).
  - `toggle(wt_path: string, branch: string, rel: string) -> boolean` — stores `git hash-object <file>` (or `"deleted"`); returns new marked state.
  - `status(wt_path: string, branch: string, rel: string) -> "reviewed"|"stale"|"todo"` — `stale` when marked hash ≠ current hash.
  - `progress(wt_path: string, branch: string, base: string) -> { rel: string, status: string }[]` over `git diff --name-only <base>` (includes uncommitted).
  - Keymaps: `<leader>gvm` (also `m` in diffview `view` and `file_panel` keymaps) toggles the current diffview file (via `require("diffview.lib").get_current_view():infer_cur_file().path`), then jumps to next file; `<leader>gvp` snacks picker over `progress()` showing `✓`/`~`/`·`, confirm opens the file.

- [ ] **Step 1: Write failing tests**

```lua
local h, m = require("tests.helpers"), require("cc.marks")
describe("cc.marks", function()
  local p, fa
  before_each(function()
    p = h.bare_project(); fa = p.wt["feat/a"]; m.file = h.tmpdir() .. "/marks.json"
    vim.fn.writefile({ "x" }, fa .. "/pis/new.py")
  end)
  after_each(h.cleanup)

  it("marks, persists and detects staleness", function()
    assert.equals("todo", m.status(fa, "feat/a", "pis/new.py"))
    assert.is_true(m.toggle(fa, "feat/a", "pis/new.py"))
    package.loaded["cc.marks"] = nil; local m2 = require("cc.marks"); m2.file = m.file
    assert.equals("reviewed", m2.status(fa, "feat/a", "pis/new.py"))
    vim.fn.writefile({ "y" }, fa .. "/pis/new.py")
    assert.equals("stale", m2.status(fa, "feat/a", "pis/new.py"))
  end)
  it("lists progress over changed files", function()
    local base = h.git(fa, { "rev-parse", "HEAD" })
    assert.same({ { rel = "pis/new.py", status = "todo" } }, m.progress(fa, "feat/a", base))
  end)
end)
```

- [ ] **Step 2: Run, expect failure** — `make test`, FAIL `module 'cc.marks' not found`.
- [ ] **Step 3: Implement `lua/cc/marks.lua`; add keymaps and progress picker to `lua/plugins/review.lua`.** Note: `git diff --name-only <base>` omits untracked files; include `git ls-files --others --exclude-standard` so the test's new file appears.
- [ ] **Step 4: Run** — `make test && make smoke`, pass.
- [ ] **Step 5: Commit**

```bash
git add lua/cc/marks.lua tests/cc/marks_spec.lua lua/plugins/review.lua
git commit -m "feat: per-file reviewed marks with staleness and progress picker"
```

---

### Task 7: Python environment resolver

**Files:**
- Create: `lua/cc/pyenv.lua`, `tests/cc/pyenv_spec.lua`

**Interfaces:**
- Produces (`require("cc.pyenv")`):
  - `root(path: string) -> string|nil` — `vim.fs.root(path, "pyproject.toml")`.
  - `venv(root: string) -> string|nil` — `<root>/.venv` iff `<root>/.venv/bin/python` is executable.
  - `tool(root: string, name: string) -> string|nil` — `<root>/.venv/bin/<name>` iff executable.
  - `M.sync_cmd = { "uv", "sync", "--frozen", "--all-groups", "--all-extras" }` (tests replace it).
  - `ensure(root: string, cb: fun(ok: boolean, err: string|nil))` — venv present → `cb(true)` (scheduled). Sync in flight for `root` → queue `cb`. Root in failed set → `cb(false, "previous sync failed; run :CcPyenvSync")` without running. Otherwise `vim.system(M.sync_cmd, { cwd = root })`; progress `vim.notify` with stable id `"cc-pyenv-"..root`; on exit success → all queued `cb(true)`; failure → add to failed set, one ERROR notify with last 20 stderr lines, all queued `cb(false, stderr)`.
  - `missing_tool_warned(root, name) -> boolean` — first call for a pair warns (`"<name> not in <root>/.venv — add dev group / run :CcPyenvSync"`) and returns `false`; later calls return `true` silently.
  - `:CcPyenvSync` — clears failed flag for the current buffer's root and calls `ensure`; `:CcPyenvInfo` — notifies root, venv, `python --version`, ty/ruff paths.

- [ ] **Step 1: Write failing tests**

```lua
local h, py = require("tests.helpers"), require("cc.pyenv")
local function fake_venv(root, tools)
  for _, t in ipairs(tools) do
    vim.fn.mkdir(root .. "/.venv/bin", "p")
    vim.fn.writefile({ "#!/bin/sh" }, root .. "/.venv/bin/" .. t); vim.uv.fs_chmod(root .. "/.venv/bin/" .. t, 493)
  end
end
describe("cc.pyenv", function()
  local d
  before_each(function()
    d = h.tmpdir()
    for _, pkg in ipairs({ "pis", "pts" }) do
      vim.fn.mkdir(d .. "/" .. pkg .. "/src/m", "p"); vim.fn.writefile({ "[project]" }, d .. "/" .. pkg .. "/pyproject.toml")
    end
    fake_venv(d .. "/pis", { "python", "ty", "ruff" }); fake_venv(d .. "/pts", { "python" })
  end)
  after_each(h.cleanup)

  it("resolves package root from deep paths regardless of cwd", function()
    vim.cmd.cd(vim.fn.tempname():match("(.*)/"))
    assert.equals(d .. "/pis", py.root(d .. "/pis/src/m/x.py"))
  end)
  it("finds pinned tools, nil when missing", function()
    assert.equals(d .. "/pis/.venv/bin/ty", py.tool(d .. "/pis", "ty"))
    assert.is_nil(py.tool(d .. "/pts", "ty"))
  end)
  it("warns once for a missing tool", function()
    assert.is_false(py.missing_tool_warned(d .. "/pts", "ty"))
    assert.is_true(py.missing_tool_warned(d .. "/pts", "ty"))
  end)
  it("runs one sync per package and fans out callbacks", function()
    vim.fn.mkdir(d .. "/new", "p"); local count_file = d .. "/count"
    py.sync_cmd = { "sh", "-c", "echo x >> " .. count_file .. "; sleep 0.2; mkdir -p .venv/bin; touch .venv/bin/python; chmod +x .venv/bin/python" }
    local oks = {}
    for _ = 1, 3 do py.ensure(d .. "/new", function(ok) table.insert(oks, ok) end) end
    vim.wait(3000, function() return #oks == 3 end)
    assert.same({ true, true, true }, oks)
    assert.equals(1, #vim.fn.readfile(count_file))
  end)
  it("does not retry a failed sync until reset", function()
    vim.fn.mkdir(d .. "/bad", "p"); py.sync_cmd = { "sh", "-c", "echo boom >&2; exit 1" }
    local r1, r2
    py.ensure(d .. "/bad", function(ok, err) r1 = { ok, err } end); vim.wait(2000, function() return r1 end)
    assert.is_false(r1[1]); assert.matches("boom", r1[2])
    py.sync_cmd = { "sh", "-c", "exit 0" }
    py.ensure(d .. "/bad", function(ok, err) r2 = { ok, err } end); vim.wait(2000, function() return r2 end)
    assert.is_false(r2[1]); assert.matches("CcPyenvSync", r2[2])
  end)
end)
```

- [ ] **Step 2: Run, expect failure** — `make test`, FAIL `module 'cc.pyenv' not found`.
- [ ] **Step 3: Implement `lua/cc/pyenv.lua`** per Interfaces (user commands created at module load are fine; `ensure` must call back via `vim.schedule`).
- [ ] **Step 4: Run, expect pass** — `make test`.
- [ ] **Step 5: Commit**

```bash
git add lua/cc/pyenv.lua tests/cc/pyenv_spec.lua
git commit -m "feat: per-package venv resolver with single-flight uv sync"
```

---

### Task 8: Python LSP (ty + ruff), formatting, tests runner

**Files:**
- Create: `lua/plugins/python.lua`
- Modify: `lua/config/options.lua`, `lazyvim.json`

**Interfaces:**
- Consumes: `cc.pyenv.root/ensure/tool/missing_tool_warned`.
- Produces:
  - `options.lua`: `vim.g.lazyvim_python_lsp = "ty"`, `vim.g.lazyvim_python_ruff = "ruff"`.
  - `lazyvim.json` extras add `lazyvim.plugins.extras.lang.python`, `lazyvim.plugins.extras.test.core`.
  - nvim-lspconfig `opts.servers`: `pyright = { enabled = false }`, `basedpyright = { enabled = false }`, and for each of `ty` (args `{"server"}`) and `ruff` (args `{"server"}`): `mason = false`;
    `root_dir = function(bufnr, on_dir)` → `r = pyenv.root(buf path)`; return if nil; `pyenv.ensure(r, cb)` where `cb(ok)`: if `ok and pyenv.tool(r, name)` → `on_dir(r)`; elseif `ok` → `pyenv.missing_tool_warned(r, name)` (server not started);
    `cmd = function(dispatchers, config) return vim.lsp.rpc.start({ pyenv.tool(config.root_dir, name), "server" }, dispatchers, { cwd = config.root_dir }) end`.
  - `linux-cultist/venv-selector.nvim` `enabled = false`.
  - conform: `formatters_by_ft.python = {}` and `default_format_opts.lsp_format = "fallback"` so python formats through the ruff client (pinned binary).
  - neotest-python: `runner = "pytest"`, `python = function(root) return { "uv", "run", "--frozen", "--project", root, "python" } end`.

- [ ] **Step 1: Verify `cmd` function signature on this Neovim**

Run: `nvim --headless "+lua print(vim.fn.has('nvim-0.12'))" +qa` → `1`. If `0` (0.11.x), `cmd` receives only `dispatchers`; instead build per-root commands inside `root_dir` by calling `vim.lsp.config(name, { cmd = {...}, cmd_cwd = r })` before `on_dir(r)` — note the choice in the commit message.

- [ ] **Step 2: Write the spec and options; sync plugins**

Run: `nvim --headless "+Lazy! sync" +qa && make smoke` → exits 0.

- [ ] **Step 3: Headless attach check against the real pipeline repo**

Create `scripts/lsp_check.lua` that opens the given file, waits up to 120 s for clients, prints `name root cmd[1]` per client:

Run: `nvim --headless -c "luafile scripts/lsp_check.lua" ~/Projects/pipeline/feat/pis-foldx/pis/<any .py under src>`
Expected: two lines, `ty …/feat/pis-foldx/pis …/feat/pis-foldx/pis/.venv/bin/ty` and same for `ruff`; no `pyright`/`basedpyright`. If that venv lacks dev tools, expect one warning and the `:CcPyenvSync` path (Review Focus 3).

Run the same on a `main/pts/*.py` file (no `.venv` yet) → `uv sync` notification, then both clients attached with root `…/main/pts`; `main/pts/.venv` now exists.

- [ ] **Step 4: Format and diagnostics parity check**

In `main/pts`, open a file, add `x = "a"`, save → becomes `x = 'a'` (ruff quote-style single). `:lua print(vim.lsp.get_clients({name='ruff'})[1].config.cmd[1])` path ends in `pts/.venv/bin/ruff`. `:Mason` shows no `ty`/`ruff` installed by this config.

- [ ] **Step 5: Test runner check** — in `main/pts`, open a test file, `<leader>tr` runs the nearest test; the output shows pytest from `pts/.venv`.

- [ ] **Step 6: Commit**

```bash
git add lua/plugins/python.lua lua/config/options.lua lazyvim.json lazy-lock.json scripts/lsp_check.lua
git commit -m "feat: ty + ruff from per-package venvs, ruff formatting, neotest via uv"
```

---

### Task 9: Other languages

**Files:**
- Create: `lua/plugins/langs.lua`
- Modify: `lazyvim.json`

**Interfaces:**
- Produces: extras `lang.yaml`, `lang.toml`, `lang.json`, `lang.markdown` in `lazyvim.json`; yamlls `settings.yaml.schemas["<otter URL from Global Constraints>"] = { "**/pis/config.yaml", "**/pts/config.yaml" }` (merged via `opts` function so SchemaStore entries stay).

- [ ] **Step 1: Add extras and spec; sync** — `nvim --headless "+Lazy! sync" +qa && make smoke` → 0.
- [ ] **Step 2: Check schema** — open `~/Projects/pipeline/main/pis/config.yaml`, add an unknown top-level key → yamlls diagnostic appears; remove it. Open a `pyproject.toml` → taplo attached (`:LspInfo`).
- [ ] **Step 3: Commit**

```bash
git add lua/plugins/langs.lua lazyvim.json lazy-lock.json
git commit -m "feat: yaml (otter schema), toml, json, markdown support"
```

---

### Task 10: Acceptance run and README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Run full checks** — `make test && make smoke` → all pass.
- [ ] **Step 2: Walk the acceptance checklist in `~/Projects/pipeline`** (start `nvim` at the root): pointer shows `⚠ no worktree` → `<leader>gw` pick `feat/pis-foldx` → `<leader>gvv` branch diff → redact one hunk in the right pane → `<leader>ghs` stage it → `m` mark file reviewed → `<leader>gvp` shows `✓` → `<leader>gvc` walk commits → while a file is open unmodified, change it from a terminal (`echo >> file`) → buffer reloads; modify buffer, change file again → warning, `:CcDiffDisk` shows both → try `<leader>gw` to `main` with the unsaved buffer → refused → `:w`/undo then switch succeeds → open `main/pts` Python file → sync + ty/ruff attached.
- [ ] **Step 3: Rewrite `README.md`** — one short section per feature with its keymaps/commands (`<leader>gw`, `<leader>gvv/gvc/gvb/gvm/gvp/gvq`, `:CcDiffDisk`, `:CcPyenvSync`, `:CcPyenvInfo`, `make test`, `make smoke`).
- [ ] **Step 4: Commit**

```bash
git add README.md && git commit -m "docs: document review-window workflow"
```
