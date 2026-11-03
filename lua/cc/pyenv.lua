local M = {}

M.sync_cmd = { "uv", "sync", "--frozen", "--all-groups", "--all-extras" }

local failed = {} ---@type table<string, boolean>
local inflight = {} ---@type table<string, fun(ok: boolean, err: string|nil)[]>
local warned = {} ---@type table<string, boolean>

---@param path string
---@return string|nil
function M.root(path)
  return vim.fs.root(path, "pyproject.toml")
end

---@param root string
---@return string|nil
function M.venv(root)
  if vim.fn.executable(root .. "/.venv/bin/python") == 1 then return root .. "/.venv" end
end

---@param root string
---@param name string
---@return string|nil
function M.tool(root, name)
  local p = root .. "/.venv/bin/" .. name
  if vim.fn.executable(p) == 1 then return p end
end

---@param root string
---@param name string
---@return boolean already_warned
function M.missing_tool_warned(root, name)
  local key = root .. "\0" .. name
  if warned[key] then return true end
  warned[key] = true
  vim.notify(("%s not in %s/.venv — add dev group / run :CcPyenvSync"):format(name, root), vim.log.levels.WARN)
  return false
end

---@param root string
---@param cb fun(ok: boolean, err: string|nil)
---@param opts? { force?: boolean } force: sync even when a venv exists
function M.ensure(root, cb, opts)
  local force = opts and opts.force
  -- join an in-flight sync first: uv creates .venv/bin/python before installing packages
  if inflight[root] then
    table.insert(inflight[root], cb)
    return
  end
  if not force and M.venv(root) then
    vim.schedule(function() cb(true) end)
    return
  end
  if failed[root] then
    vim.schedule(function() cb(false, "previous sync failed; run :CcPyenvSync") end)
    return
  end

  inflight[root] = { cb }
  local id = "cc-pyenv-" .. root
  vim.notify("uv sync in " .. root .. " ...", vim.log.levels.INFO, { id = id, title = "cc.pyenv" })

  local function finish(ok, err)
    local cbs = inflight[root]
    inflight[root] = nil
    if ok then
      warned = {}
      vim.notify("uv sync done: " .. root, vim.log.levels.INFO, { id = id, title = "cc.pyenv" })
    else
      failed[root] = true
      local lines = vim.split(vim.trim(err or ""), "\n")
      local tail = table.concat(vim.list_slice(lines, math.max(1, #lines - 19)), "\n")
      vim.notify(("uv sync failed in %s:\n%s"):format(root, tail), vim.log.levels.ERROR, { id = id, title = "cc.pyenv" })
    end
    for _, f in ipairs(cbs or {}) do
      if ok then f(true) else f(false, err) end
    end
  end

  local started, obj = pcall(vim.system, M.sync_cmd, { cwd = root, text = true }, function(res)
    vim.schedule(function()
      if res.code == 0 then
        finish(true)
      else
        finish(false, (res.stderr and res.stderr ~= "") and res.stderr or ("exit code " .. res.code))
      end
    end)
  end)
  if not started then
    -- e.g. uv not installed: spawn error is thrown synchronously
    vim.schedule(function() finish(false, tostring(obj)) end)
  end
end

local LSP_NAMES = { ty = true, ruff = true }

--- ty/ruff clients whose root is not inside `path` (they belong to another worktree).
---@param path string
---@return vim.lsp.Client[]
function M.foreign_clients(path)
  path = vim.uv.fs_realpath(path) or path
  local out = {}
  for _, c in ipairs(vim.lsp.get_clients()) do
    if LSP_NAMES[c.name] then
      local r = c.root_dir and (vim.uv.fs_realpath(c.root_dir) or c.root_dir)
      if not r or (r ~= path and r:sub(1, #path + 1) ~= path .. "/") then out[#out + 1] = c end
    end
  end
  return out
end

---@param path string
function M.stop_foreign_clients(path)
  for _, c in ipairs(M.foreign_clients(path)) do c:stop() end
end

--- neotest-python adapter running pytest via `uv run` with the package root as cwd.
function M.neotest_adapter()
  local adapter = require("neotest-python")({
    runner = "pytest",
    python = function(root) return { "uv", "run", "--frozen", "--project", root, "python" } end,
  })
  local build_spec = adapter.build_spec
  adapter.build_spec = function(args)
    local spec = build_spec(args)
    local pos = args.tree:data()
    -- same root neotest-python passed to `python` above
    local root = spec and pos and require("neotest-python.base").get_root(pos.path)
    if root then
      spec.cwd = root
      if spec.strategy then spec.strategy.cwd = root end
    end
    return spec
  end
  return adapter
end

local function current_root()
  local name = vim.api.nvim_buf_get_name(0)
  local root = name ~= "" and M.root(name) or nil
  if not root then vim.notify("cc.pyenv: current buffer is not in a Python package", vim.log.levels.WARN) end
  return root
end

vim.api.nvim_create_user_command("CcPyenvSync", function()
  local root = current_root()
  if not root then return end
  failed[root] = nil
  warned = {}
  M.ensure(root, function() end, { force = true })
end, { desc = "Run uv sync for the current buffer's Python package" })

vim.api.nvim_create_user_command("CcPyenvInfo", function()
  local root = current_root()
  if not root then return end
  local venv = M.venv(root)
  local version = "n/a"
  if venv then
    local ok, res = pcall(function() return vim.system({ venv .. "/bin/python", "--version" }, { text = true }):wait(2000) end)
    if ok and res.code == 0 then version = vim.trim((res.stdout or "") .. (res.stderr or "")) end
  end
  vim.notify(table.concat({
    "root: " .. root,
    "venv: " .. (venv or "missing"),
    "python: " .. version,
    "ty: " .. (M.tool(root, "ty") or "missing"),
    "ruff: " .. (M.tool(root, "ruff") or "missing"),
  }, "\n"), vim.log.levels.INFO, { title = "cc.pyenv" })
end, { desc = "Show Python environment for the current buffer" })

return M
