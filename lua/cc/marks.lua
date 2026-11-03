local M = {}

M.file = vim.fn.stdpath("state") .. "/cc-review-marks.json"

local warned = false

---@return table
local function load()
  local f = io.open(M.file, "r")
  if not f then return {} end
  local raw = f:read("*a")
  f:close()
  if vim.trim(raw) == "" then return {} end
  local ok, data = pcall(vim.json.decode, raw)
  if ok and type(data) == "table" then return data end
  if not warned then
    warned = true
    vim.notify("cc.marks: corrupt marks file, treating as empty: " .. M.file, vim.log.levels.WARN)
  end
  return {}
end

---@param data table
local function save(data)
  vim.fn.mkdir(vim.fs.dirname(M.file), "p")
  local f = io.open(M.file, "w")
  if not f then
    vim.notify("cc.marks: cannot write " .. M.file, vim.log.levels.ERROR)
    return
  end
  f:write(vim.json.encode(data))
  f:close()
end

--- Hash of the file's current content, or "deleted" when it is gone.
---@param wt_path string
---@param rel string
---@return string
local function current_hash(wt_path, rel)
  if not vim.uv.fs_stat(wt_path .. "/" .. rel) then return "deleted" end
  local res = vim.system({ "git", "-C", wt_path, "hash-object", "--", rel }, { text = true }):wait()
  if res.code ~= 0 then return "deleted" end
  return vim.trim(res.stdout or "")
end

---@param data table
---@param wt_path string
---@param branch string
---@param create boolean
---@return table|nil
local function bucket(data, wt_path, branch, create)
  local w = data[wt_path]
  if not w then
    if not create then return nil end
    w = {}; data[wt_path] = w
  end
  local b = w[branch]
  if not b then
    if not create then return nil end
    b = {}; w[branch] = b
  end
  return b
end

---@return boolean new marked state
function M.toggle(wt_path, branch, rel)
  local data = load()
  local b = bucket(data, wt_path, branch, true)
  local marked = b[rel] == nil
  b[rel] = marked and current_hash(wt_path, rel) or nil
  save(data)
  return marked
end

---@return "reviewed"|"stale"|"todo"
function M.status(wt_path, branch, rel)
  local b = bucket(load(), wt_path, branch, false)
  local stored = b and b[rel]
  if not stored then return "todo" end
  return stored == current_hash(wt_path, rel) and "reviewed" or "stale"
end

---@return { rel: string, status: string }[]
function M.progress(wt_path, branch, base)
  local seen, rels = {}, {}
  local function collect(args)
    local cmd = { "git", "-C", wt_path }
    vim.list_extend(cmd, args)
    local res = vim.system(cmd, { text = true }):wait()
    for line in (res.stdout or ""):gmatch("[^\n]+") do
      if not seen[line] then seen[line] = true; rels[#rels + 1] = line end
    end
  end
  collect({ "-c", "core.quotepath=off", "diff", "--name-only", base })
  collect({ "-c", "core.quotepath=off", "ls-files", "--others", "--exclude-standard" })
  table.sort(rels)
  local out = {}
  for _, rel in ipairs(rels) do
    out[#out + 1] = { rel = rel, status = M.status(wt_path, branch, rel) }
  end
  return out
end

--- Detached worktrees share one stable key.
---@param wt Worktree
local function key(wt) return wt.branch or "(detached)" end

--- Toggle the file under the cursor in the current diffview, then go to the next file.
function M.toggle_current()
  local wt = require("cc.worktree").active()
  if not wt then
    vim.notify("pick a worktree first", vim.log.levels.WARN)
    return
  end
  local view = require("diffview.lib").get_current_view()
  local file = view and view.infer_cur_file and view:infer_cur_file()
  if not file or not file.path then
    vim.notify("no file under cursor in a diffview", vim.log.levels.WARN)
    return
  end
  local marked = M.toggle(wt.path, key(wt), file.path)
  vim.notify((marked and "reviewed: " or "unmarked: ") .. file.path)
  require("diffview.config").actions.select_next_entry()
end

function M.pick_progress()
  local wt = require("cc.worktree").active()
  if not wt then
    vim.notify("pick a worktree first", vim.log.levels.WARN)
    return
  end
  local base, err = require("cc.review").base(wt.path)
  if not base then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  local icons = { reviewed = "✓", stale = "~", todo = "·" }
  local items, done = {}, 0
  for _, e in ipairs(M.progress(wt.path, key(wt), base)) do
    if e.status == "reviewed" then done = done + 1 end
    items[#items + 1] = {
      text = e.rel,
      label = icons[e.status] .. " " .. e.rel,
      file = wt.path .. "/" .. e.rel,
    }
  end
  Snacks.picker.pick({
    title = ("Review progress %d/%d"):format(done, #items),
    items = items,
    preview = "file",
    format = function(item) return { { item.label } } end,
    confirm = function(picker, item)
      picker:close()
      if item then vim.cmd.edit(vim.fn.fnameescape(item.file)) end
    end,
  })
end

return M
