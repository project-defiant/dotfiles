local h = require("tests.helpers")
local spec = require("plugins.python")

local function lsp_opts()
  for _, s in ipairs(spec) do
    if s[1] == "neovim/nvim-lspconfig" then return s.opts.servers end
  end
end

--- In-process stand-in for an LSP server: answers initialize/shutdown, exits on `exit`.
local function fake_server(dispatchers)
  local closing = false
  local function close()
    if closing then return end
    closing = true
    vim.schedule(function() dispatchers.on_exit(0, 15) end)
  end
  return {
    request = function(method, _, callback)
      vim.schedule(function()
        if method == "initialize" then callback(nil, { capabilities = {} }) else callback(nil, vim.NIL) end
      end)
      return true, 1
    end,
    notify = function(method)
      if method == "exit" then close() end
      return true
    end,
    is_closing = function() return closing end,
    terminate = close,
  }
end

describe("plugins.python", function()
  after_each(function()
    for _, c in ipairs(vim.lsp.get_clients()) do c:stop(true) end
    vim.wait(1000, function() return #vim.lsp.get_clients() == 0 end)
    vim.cmd("silent! %bwipeout!")
    h.cleanup()
  end)

  it("stops ty/ruff clients rooted outside the new worktree on CcWorktreeChanged", function()
    local d = h.tmpdir()
    local inside, foreign = d .. "/wt/pis", d .. "/other/pis"
    vim.fn.mkdir(inside, "p"); vim.fn.mkdir(foreign, "p")
    local buf = vim.api.nvim_create_buf(true, true)
    local function start(name, root)
      return vim.lsp.start({ name = name, cmd = fake_server, root_dir = root }, { bufnr = buf })
    end
    local ty_foreign, ruff_foreign = start("ty", foreign), start("ruff", foreign)
    local ty_inside, other = start("ty", inside), start("lua_ls", foreign)
    assert.is_true(vim.wait(2000, function()
      return #vim.tbl_filter(function(c) return c.initialized end, vim.lsp.get_clients()) == 4
    end))

    vim.api.nvim_exec_autocmds("User", { pattern = "CcWorktreeChanged", data = { path = d .. "/wt" } })

    assert.is_true(vim.wait(2000, function()
      return vim.lsp.get_client_by_id(ty_foreign) == nil and vim.lsp.get_client_by_id(ruff_foreign) == nil
    end))
    assert.is_not_nil(vim.lsp.get_client_by_id(ty_inside))
    assert.is_not_nil(vim.lsp.get_client_by_id(other))
  end)

  it("root_dir skips unnamed buffers and buffers wiped before the venv is ready", function()
    local d = h.tmpdir()
    vim.fn.writefile({ "[project]" }, d .. "/pyproject.toml")
    vim.fn.mkdir(d .. "/.venv/bin", "p")
    for _, t in ipairs({ "python", "ty" }) do
      vim.fn.writefile({ "#!/bin/sh" }, d .. "/.venv/bin/" .. t); vim.uv.fs_chmod(d .. "/.venv/bin/" .. t, 493)
    end
    local root_dir = lsp_opts().ty.root_dir
    local got = {}
    local function on_dir(r) got[#got + 1] = r end

    vim.cmd.cd(d)
    root_dir(vim.api.nvim_create_buf(true, false), on_dir) -- unnamed: must not resolve from cwd

    vim.cmd.edit(d .. "/x.py")
    local wiped = vim.api.nvim_get_current_buf()
    root_dir(wiped, on_dir)
    vim.api.nvim_buf_delete(wiped, { force = true })

    vim.cmd.edit(d .. "/y.py")
    root_dir(vim.api.nvim_get_current_buf(), on_dir)

    assert.is_true(vim.wait(1000, function() return #got > 0 end))
    vim.wait(100)
    assert.same({ d }, got)
  end)
end)

describe("neotest-python adapter", function()
  local lazy = vim.fn.stdpath("data") .. "/lazy/"
  for _, p in ipairs({ "nvim-nio", "neotest", "neotest-python" }) do vim.opt.runtimepath:append(lazy .. p) end
  after_each(h.cleanup)

  it("runs pytest via uv from the package root, not the cwd", function()
    local d = h.tmpdir()
    vim.fn.mkdir(d .. "/pis/tests", "p")
    vim.fn.writefile({ "[project]" }, d .. "/pis/pyproject.toml")
    local file = d .. "/pis/tests/test_x.py"
    vim.fn.writefile({ "def test_a(): pass" }, file)
    vim.cmd.cd(d)
    local adapter = require("cc.pyenv").neotest_adapter()
    local tree = { data = function() return { id = file, path = file, type = "file" } end }
    local rs
    require("nio").run(function() rs = adapter.build_spec({ tree = tree }) end)
    assert.is_true(vim.wait(2000, function() return rs ~= nil end))
    assert.equals(d .. "/pis", rs.cwd)
    assert.same({ "uv", "run", "--frozen", "--project", d .. "/pis", "python" }, vim.list_slice(rs.command, 1, 6))
    assert.equals(file, rs.command[#rs.command])
    rs.context.stop_stream()
  end)
end)
