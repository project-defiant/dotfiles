local M = {}

local created = {}

---@return string realpath of a fresh temp directory
function M.tmpdir()
  local path = vim.fn.tempname()
  vim.fn.mkdir(path, "p")
  path = vim.uv.fs_realpath(path) or path
  created[#created + 1] = path
  return path
end

function M.cleanup()
  for _, p in ipairs(created) do
    vim.fn.delete(p, "rf")
  end
  created = {}
end

---@param dir string
---@param args string[]
---@return string
function M.git(dir, args)
  local cmd = { "git", "-C", dir }
  vim.list_extend(cmd, args)
  local res = vim.system(cmd, { text = true }):wait()
  if res.code ~= 0 then
    error(("git %s failed (%d): %s"):format(table.concat(args, " "), res.code, res.stderr or ""))
  end
  return vim.trim(res.stdout or "")
end

---@param opts? { main?: string }
---@return { root: string, wt: table<string,string> }
function M.bare_project(opts)
  local main = (opts and opts.main) or "main"
  local root = M.tmpdir()
  local bare = root .. "/.bare"
  vim.fn.mkdir(bare, "p")
  M.git(bare, { "init", "--bare", "--initial-branch=" .. main })
  M.git(bare, { "config", "user.name", "Test" })
  M.git(bare, { "config", "user.email", "test@example.com" })
  vim.fn.writefile({ "gitdir: ./.bare" }, root .. "/.git")

  -- initial commit on trunk via a throwaway worktree
  local wt = {}
  M.git(root, { "worktree", "add", "--orphan", "-b", main, root .. "/" .. main })
  for _, pkg in ipairs({ "pis", "pts" }) do
    vim.fn.mkdir(root .. "/" .. main .. "/" .. pkg, "p")
    vim.fn.writefile({ "[project]", 'name = "' .. pkg .. '"' }, root .. "/" .. main .. "/" .. pkg .. "/pyproject.toml")
  end
  M.git(root .. "/" .. main, { "add", "-A" })
  M.git(root .. "/" .. main, { "commit", "-m", "init" })
  wt[main] = root .. "/" .. main

  local function add(branch, folder)
    M.git(root, { "worktree", "add", "-b", branch, folder, main })
    wt[branch] = folder
  end
  add("feat/a", root .. "/feat/a")
  add("credible", root .. "/feat/credible")
  add("feat/nested", root .. "/" .. main .. "/feat/nested")
  return { root = root, wt = wt }
end

return M
