-- Acceptance walk-through for the review window, run headless against a real
-- multi-worktree repo. Does not modify tracked files: scratch files live in a temp dir
-- and the marks file is redirected. Step 8 opens a real Python file, so the normal
-- environment sync may create that package's .venv and ty/ruff caches. Start nvim with the cwd at the project root
-- (the bare repo's parent), which is not itself a worktree:
--
--   cd ~/Projects/pipeline && nvim --headless -c "luafile ~/.config/nvim/scripts/acceptance.lua"
--
-- Env overrides: CC_ACC_BRANCH (default feat/pis-foldx), CC_ACC_MAIN (main),
-- CC_ACC_PYFILE (path of a .py file inside the main worktree, relative to it;
-- default: first tracked .py under pts/).
-- Prints PASS/FAIL per step; exits 1 if any step fails.

local results = {}
local function step(name, fn)
  local ok, res, detail = pcall(fn)
  local pass = ok and res == true
  results[#results + 1] = pass
  local info = ok and (detail or "") or tostring(res)
  io.stdout:write(("%s  %s%s\n"):format(pass and "PASS" or "FAIL", name, info ~= "" and ("  -- " .. info) or ""))
end

local tmp, orig_notify

local function run()
  local wtm = require("cc.worktree")
  local ui = require("cc.worktree_ui")
  local marks = require("cc.marks")
  local review = require("cc.review")

  local root = vim.uv.cwd()
  local branch = vim.env.CC_ACC_BRANCH or "feat/pis-foldx"
  local main_branch = vim.env.CC_ACC_MAIN or "main"
  tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  marks.file = tmp .. "/marks.json"

  local notes = {}
  orig_notify = vim.notify
  vim.notify = function(msg, ...)
    notes[#notes + 1] = tostring(msg)
    return orig_notify(msg, ...)
  end

  local function find(b)
    for _, w in ipairs(wtm.list(root)) do
      if w.branch == b then return w end
    end
  end
  local function view_kind()
    local ok, lib = pcall(require, "diffview.lib")
    local v = ok and lib.get_current_view()
    return v and (v.class and v.class.__name or v.__index and "view") or nil, v
  end
  local function wait(ms, cond) return vim.wait(ms, cond or function() return false end, 50) end

  wait(1000)
  -- A headless nvim has no UIEnter, so lazy.nvim never fires VeryLazy and lua/config/autocmds.lua
  -- (which sets up cc.worktree and cc.disksync) has not run. Fire it once, as the TUI would.
  if vim.fn.exists(":CcDiffDisk") == 0 then
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
  end
  wait(500)

  step("1 start at root: no active worktree, pointer warns", function()
    wtm.setup()
    return wtm.active() == nil and ui.pointer() == "⚠ no worktree", ui.pointer()
  end)

  local feat = find(branch)
  local main = find(main_branch)

  step("2 switch to " .. branch, function()
    assert(feat, "worktree not found: " .. branch)
    local ok, err = wtm.switch(feat.path)
    return ok == true and wtm.active().branch == branch and vim.uv.cwd() == feat.path, err or ui.pointer()
  end)

  step("3 branch diff opens a diffview", function()
    review.open_branch()
    local _, v = view_kind()
    local ok = wait(15000, function()
      _, v = view_kind()
      return v and v.panel and #v.panel:ordered_file_list() > 0
    end)
    return ok and v ~= nil, ok and (#v.panel:ordered_file_list() .. " files") or "no view"
  end)

  step("4 toggle reviewed (temp marks file) and progress shows a check", function()
    local _, v = view_kind()
    local list = v.panel:ordered_file_list()
    assert(#list > 0, "no files in view")
    v:set_file(list[1], true)
    wait(1500)
    marks.toggle_current()
    local base = assert(review.base(feat.path))
    local done = 0
    for _, e in ipairs(marks.progress(feat.path, feat.branch, base)) do
      if e.status == "reviewed" then done = done + 1 end
    end
    pcall(marks.pick_progress)
    wait(500)
    local title
    pcall(function() title = Snacks.picker.get()[1].opts.title end)
    pcall(function() Snacks.picker.get()[1]:close() end)
    return done == 1 and title ~= nil and title:match("^Review progress 1/") ~= nil, ("reviewed=%d picker=%s"):format(done, tostring(title))
  end)

  step("5 commit walk opens a file history view", function()
    vim.cmd("DiffviewClose")
    wait(500)
    review.open_commits()
    local ok = wait(15000, function()
      local _, v = view_kind()
      return v and v.panel and v.panel.entries and #v.panel.entries > 0
    end)
    local name = view_kind()
    vim.cmd("DiffviewClose")
    wait(500)
    return ok, tostring(name)
  end)

  step("6a disk sync: unmodified buffer reloads", function()
    local f = tmp .. "/sync.txt"
    vim.fn.writefile({ "one" }, f)
    vim.cmd.edit(vim.fn.fnameescape(f))
    wait(1100) -- mtime granularity
    vim.fn.system({ "sh", "-c", "echo two >> " .. vim.fn.shellescape(f) })
    vim.cmd("checktime")
    wait(2000, function() return vim.api.nvim_buf_line_count(0) == 2 end)
    return vim.api.nvim_buf_line_count(0) == 2, "lines=" .. vim.api.nvim_buf_line_count(0)
  end)

  step("6b disk sync: modified buffer kept, warning shown, :CcDiffDisk diffs", function()
    local f = tmp .. "/sync.txt"
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { "local edit" })
    wait(1100)
    vim.fn.system({ "sh", "-c", "echo three >> " .. vim.fn.shellescape(f) })
    notes = {}
    vim.cmd("checktime")
    wait(2000, function() return vim.b.cc_disk_conflict ~= nil end)
    local kept = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "local edit" and vim.bo.modified
    local warned = false
    for _, n in ipairs(notes) do warned = warned or n:find("changed on disk", 1, true) ~= nil end
    local before = #vim.api.nvim_tabpage_list_wins(0)
    vim.cmd("CcDiffDisk")
    local diffwins = 0
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.wo[w].diff then diffwins = diffwins + 1 end
    end
    vim.cmd("diffoff!")
    vim.cmd("only")
    vim.cmd("enew")
    vim.cmd("bwipeout! " .. vim.fn.fnameescape(f))
    return kept and warned and diffwins == 2 and #vim.api.nvim_tabpage_list_wins(0) <= before,
      ("kept=%s warned=%s diff_windows=%d"):format(kept, warned, diffwins)
  end)

  step("7 switch refused with an unsaved buffer, succeeds after it is wiped", function()
    assert(main, "worktree not found: " .. main_branch)
    local scratch = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(scratch, feat.path .. "/.cc-acceptance-scratch.txt") -- never written
    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { "unsaved" })
    vim.bo[scratch].modified = true
    local ok1, err1 = wtm.switch(main.path)
    local refused = ok1 == false and tostring(err1):match("^unsaved") ~= nil and wtm.active().branch == branch
    vim.cmd("bwipeout! " .. scratch)
    local ok2 = wtm.switch(main.path)
    return refused and ok2 == true and wtm.active().branch == main_branch, ("refused=%s (%s) then switched=%s"):format(refused, tostring(err1), tostring(ok2))
  end)

  step("8 python file in main/pts attaches ty + ruff from main/pts/.venv", function()
    local rel = vim.env.CC_ACC_PYFILE
    if not rel then
      local out = vim.fn.systemlist({ "git", "-C", main.path, "ls-files", "pts/*.py" })
      rel = out[1]
    end
    assert(rel and rel ~= "", "no python file found")
    vim.cmd.edit(vim.fn.fnameescape(main.path .. "/" .. rel))
    local buf = vim.api.nvim_get_current_buf()
    local ok = wait(120000, function()
      local got = {}
      for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do got[c.name] = c.initialized end
      return got.ty and got.ruff
    end)
    local bins, parts = {}, {}
    for _, pid in ipairs(vim.api.nvim_get_proc_children(vim.fn.getpid())) do
      local cmd = vim.trim(vim.system({ "ps", "-o", "command=", "-p", tostring(pid) }, { text = true }):wait().stdout or "")
      bins[#bins + 1] = cmd:match("^(%S+)")
    end
    local expect = main.path .. "/pts"
    local good = ok
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
      parts[#parts + 1] = c.name .. " root=" .. tostring(c.root_dir)
      if (c.name == "ty" or c.name == "ruff") and c.root_dir ~= expect then good = false end
    end
    local venv_bins = 0
    for _, b in ipairs(bins) do
      if b and b:find(expect .. "/.venv/bin/", 1, true) == 1 then venv_bins = venv_bins + 1 end
    end
    return good and venv_bins >= 2, table.concat(parts, "; ") .. ("; children from .venv/bin: %d"):format(venv_bins)
  end)

end

local ok, err = pcall(run)
if not ok then
  io.stderr:write("acceptance: aborted: " .. tostring(err) .. "\n")
  results[#results + 1] = false
end
if orig_notify then vim.notify = orig_notify end
if tmp then vim.fn.delete(tmp, "rf") end
local failed = 0
for _, p in ipairs(results) do if not p then failed = failed + 1 end end
io.stdout:write(("acceptance: %d/%d steps passed\n"):format(#results - failed, #results))
vim.cmd(failed == 0 and "qall!" or "cquit 1")
