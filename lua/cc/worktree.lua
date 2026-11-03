local M = {}

---@class Worktree
---@field path string
---@field branch string|nil
---@field head string
---@field detached boolean

---@type Worktree|nil
local current

--- Normalise a path: absolute, symlinks resolved. For paths that do not exist,
--- resolves the nearest existing ancestor and appends the remainder.
---@param path string
---@return string
local function norm(path)
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  if #path > 1 then path = path:gsub("/+$", "") end
  local rest = {}
  local probe = path
  while probe ~= "" and probe ~= "/" do
    local real = vim.uv.fs_realpath(probe)
    if real then
      for i = #rest, 1, -1 do real = real .. "/" .. rest[i] end
      return real
    end
    rest[#rest + 1] = vim.fs.basename(probe)
    probe = vim.fs.dirname(probe)
  end
  return path
end

---@param dir? string
---@return Worktree[]
function M.list(dir)
  local res = vim.system({ "git", "-C", dir or vim.uv.cwd(), "worktree", "list", "--porcelain" }, { text = true }):wait()
  if res.code ~= 0 then return {} end
  local out = {}
  for block in ((res.stdout or "") .. "\n\n"):gmatch("(.-)\n\n") do
    local wt = { head = "", detached = false }
    local skip = false
    for line in block:gmatch("[^\n]+") do
      local key, val = line:match("^(%S+)%s?(.*)$")
      if key == "worktree" then
        wt.path = norm(val)
      elseif key == "HEAD" then
        wt.head = val
      elseif key == "branch" then
        wt.branch = val:gsub("^refs/heads/", "")
      elseif key == "detached" then
        wt.detached = true
      elseif key == "bare" or key == "prunable" then
        skip = true
      end
    end
    if wt.path and not skip then out[#out + 1] = wt end
  end
  table.sort(out, function(a, b) return (a.branch or a.path) < (b.branch or b.path) end)
  return out
end

---@param path string
---@param wts? Worktree[]
---@return Worktree|nil
function M.owner(path, wts)
  wts = wts or M.list()
  path = norm(path)
  local best
  for _, w in ipairs(wts) do
    if path == w.path or path:sub(1, #w.path + 1) == w.path .. "/" then
      if not best or #w.path > #best.path then best = w end
    end
  end
  return best
end

---@return Worktree|nil
function M.active() return current end

---@param wt Worktree
---@param wts? Worktree[]
---@return string[]
function M.nested(wt, wts)
  wts = wts or M.list(wt.path)
  local prefix = wt.path .. "/"
  local out = {}
  for _, w in ipairs(wts) do
    if w.path ~= wt.path and w.path:sub(1, #prefix) == prefix then
      out[#out + 1] = w.path:sub(#prefix + 1)
    end
  end
  table.sort(out)
  return out
end

--- Project root: parent dir of the git common dir (the bare repo's parent, or the main checkout).
---@param path string
---@return string|nil
function M.root(path)
  local res = vim.system({ "git", "-C", path, "rev-parse", "--path-format=absolute", "--git-common-dir" }, { text = true }):wait()
  if res.code ~= 0 then return nil end
  return norm(vim.fs.dirname(vim.trim(res.stdout)))
end

---@param w Worktree
---@param root? string project root, derived from `w` when omitted
---@return string
function M.label(w, root)
  root = root or M.root(w.path) or vim.fs.dirname(w.path)
  local rel = w.path
  if w.path == root then
    rel = "" -- main checkout of an ordinary (non-bare) repo
  elseif w.path:sub(1, #root + 1) == root .. "/" then
    rel = w.path:sub(#root + 2)
  end
  if w.detached or not w.branch then return vim.trim("(detached) " .. rel) end
  if rel == "" or rel == w.branch then return w.branch end
  return w.branch .. "  (" .. rel .. ")"
end

---@param path string
---@return boolean, string|nil
function M.switch(path)
  local target_path = norm(path)
  local old = current
  if old and old.path == target_path then return true end
  local wts = M.list(target_path)
  local target = M.owner(target_path, wts)
  if not target then return false, "not a worktree: " .. path end

  -- every file buffer (loaded, or unloaded but listed) owned by a worktree other than the target;
  -- buffers outside all worktrees (owner nil) are left alone
  local owned, unsaved = {}, {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(b)
    local loaded = vim.api.nvim_buf_is_loaded(b)
    if name ~= "" and not name:match("^%w+://") and vim.bo[b].buftype == ""
      and (loaded or vim.bo[b].buflisted) then
      local o = M.owner(name, wts)
      if o and o.path ~= target.path then
        owned[#owned + 1] = b
        if loaded and vim.bo[b].modified then unsaved[#unsaved + 1] = vim.fn.fnamemodify(name, ":.") end
      end
    end
  end
  if #unsaved > 0 then return false, "unsaved: " .. table.concat(unsaved, ", ") end

  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local is_diffview = false
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
      if name:match("^diffview://") or vim.bo[vim.api.nvim_win_get_buf(w)].filetype:match("^Diffview") then
        is_diffview = true
        break
      end
    end
    if is_diffview and vim.api.nvim_tabpage_is_valid(tab) then
      vim.api.nvim_set_current_tabpage(tab)
      pcall(vim.cmd, "DiffviewClose")
    end
  end

  for _, b in ipairs(owned) do
    if vim.api.nvim_buf_is_valid(b) then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
  end

  vim.cmd.cd(vim.fn.fnameescape(target.path))
  current = target
  vim.api.nvim_exec_autocmds("User", { pattern = "CcWorktreeChanged", data = target })
  return true
end

--- Idempotent: (re)derives the active worktree from the cwd.
function M.setup()
  current = M.owner(vim.uv.cwd(), M.list())
end

return M
