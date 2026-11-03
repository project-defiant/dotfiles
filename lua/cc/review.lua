local M = {}

---@type table<string,string>
local overrides = {}

---@param path string
---@param args string[]
---@return string|nil
local function git(path, args)
  local cmd = { "git", "-C", path }
  vim.list_extend(cmd, args)
  local res = vim.system(cmd, { text = true }):wait()
  if res.code ~= 0 then return nil end
  local out = vim.trim(res.stdout or "")
  return out ~= "" and out or nil
end

---@param wt_path string
---@param ref string|nil
function M.set_override(wt_path, ref) overrides[wt_path] = ref end

---@param wt_path string
---@return string|nil sha
---@return string|nil err
function M.base(wt_path)
  local override = overrides[wt_path]
  if override then
    local sha = git(wt_path, { "merge-base", override, "HEAD" })
    if sha then return sha end
    return nil, ("no base: cannot merge-base %s with HEAD"):format(override)
  end
  for _, ref in ipairs({ "origin/main", "main" }) do
    local sha = git(wt_path, { "merge-base", ref, "HEAD" })
    if sha then return sha end
  end
  return nil, "no base: neither origin/main nor main found"
end

---@return string|nil sha, string|nil path
local function resolve()
  local wt = require("cc.worktree").active()
  if not wt then
    vim.notify("pick a worktree first", vim.log.levels.WARN)
    return
  end
  local sha, err = M.base(wt.path)
  if not sha then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  return sha, wt.path
end

function M.open_branch()
  local sha = resolve()
  if sha then vim.cmd("DiffviewOpen " .. sha) end
end

function M.open_commits()
  local sha = resolve()
  if sha then vim.cmd("DiffviewFileHistory --range=" .. sha .. "..HEAD") end
end

function M.pick_base()
  local wt = require("cc.worktree").active()
  if not wt then
    vim.notify("pick a worktree first", vim.log.levels.WARN)
    return
  end
  local out = git(wt.path, { "for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes" })
  local items = {}
  for ref in (out or ""):gmatch("[^\n]+") do
    items[#items + 1] = { text = ref, ref = ref }
  end
  Snacks.picker.pick({
    title = "Review base",
    items = items,
    preview = "none",
    format = "text",
    confirm = function(picker, item)
      picker:close()
      if item then M.set_override(wt.path, item.ref) end
    end,
  })
end

return M
