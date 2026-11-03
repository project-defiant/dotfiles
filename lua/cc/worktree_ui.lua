local M = {}

local function wt() return require("cc.worktree") end

--- Picker items for every worktree; the active one is flagged.
function M.items()
  local w = wt()
  local act = w.active()
  local list = w.list(act and act.path or nil)
  local root = list[1] and w.root(list[1].path)
  local out = {}
  for _, x in ipairs(list) do
    local is_active = act ~= nil and act.path == x.path
    out[#out + 1] = {
      text = w.label(x, root),
      file = x.path,
      wt = x,
      active = is_active,
    }
  end
  return out
end

--- Text for the lualine pointer.
function M.pointer()
  local a = wt().active()
  if not a then return "⚠ no worktree" end
  return " " .. (a.branch or "(detached)")
end

--- Add the active worktree's nested worktrees to a picker's excludes.
function M.exclude_nested(opts)
  local a = wt().active()
  if a then
    local seen = {}
    local merged = {}
    for _, e in ipairs(vim.list_extend(vim.deepcopy(opts.exclude or {}), wt().nested(a))) do
      if not seen[e] then seen[e] = true; merged[#merged + 1] = e end
    end
    opts.exclude = merged
  end
  return opts
end

return M
