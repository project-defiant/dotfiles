-- Usage: nvim --headless -c "luafile scripts/lsp_check.lua" <file.py>
-- Opens <file>, waits up to 120 s for the ty + ruff clients to initialize, then prints
-- `name root cmd[1]` per attached client. cmd is a function (per-root binary), so cmd[1]
-- is read from the spawned child process. Exits 1 on timeout.
local file = vim.fn.argv(0)
if file == "" then
  io.stderr:write("lsp_check: no file given\n")
  vim.cmd("cquit 2")
end
vim.cmd.edit(vim.fn.fnameescape(file))
local buf = vim.api.nvim_get_current_buf()

local function ready()
  local got = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    got[c.name] = c.initialized
  end
  return got.ty and got.ruff
end

-- argv[0] of each child process of this nvim, keyed by basename
local function child_bins()
  local bins = {}
  for _, pid in ipairs(vim.api.nvim_get_proc_children(vim.fn.getpid())) do
    local out = vim.system({ "ps", "-o", "command=", "-p", tostring(pid) }, { text = true }):wait()
    local bin = vim.trim(out.stdout or ""):match("^(%S+)")
    if bin then
      bins[vim.fs.basename(bin)] = bin
    end
  end
  return bins
end

local ok = vim.wait(120000, ready, 200)
local bins = child_bins()
for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
  local cmd = c.config.cmd
  local bin = type(cmd) == "table" and cmd[1] or bins[c.name] or "?"
  io.stdout:write(("%s %s %s\n"):format(c.name, c.root_dir or "-", bin))
end
if not ok then
  io.stderr:write("lsp_check: timeout waiting for ty + ruff\n")
  vim.cmd("cquit 1")
end
vim.cmd("qall!")
