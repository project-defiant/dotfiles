local h, py = require("tests.helpers"), require("cc.pyenv")
local function fake_venv(root, tools)
  for _, t in ipairs(tools) do
    vim.fn.mkdir(root .. "/.venv/bin", "p")
    vim.fn.writefile({ "#!/bin/sh" }, root .. "/.venv/bin/" .. t); vim.uv.fs_chmod(root .. "/.venv/bin/" .. t, 493)
  end
end
describe("cc.pyenv", function()
  local d, orig_notify, notes, orig_cmd
  before_each(function()
    orig_notify, orig_cmd = vim.notify, py.sync_cmd
    notes = {}
    vim.notify = function(msg, level, opts) table.insert(notes, { msg = msg, level = level, opts = opts }) end
    d = h.tmpdir()
    for _, pkg in ipairs({ "pis", "pts" }) do
      vim.fn.mkdir(d .. "/" .. pkg .. "/src/m", "p"); vim.fn.writefile({ "[project]" }, d .. "/" .. pkg .. "/pyproject.toml")
    end
    fake_venv(d .. "/pis", { "python", "ty", "ruff" }); fake_venv(d .. "/pts", { "python" })
  end)
  after_each(function()
    vim.notify, py.sync_cmd = orig_notify, orig_cmd
    h.cleanup()
  end)

  it("has the repo's uv sync command by default", function()
    assert.same({ "uv", "sync", "--frozen", "--all-groups", "--all-extras" }, orig_cmd)
  end)
  it("resolves package root from deep paths regardless of cwd", function()
    vim.cmd.cd(vim.fn.tempname():match("(.*)/"))
    assert.equals(d .. "/pis", py.root(d .. "/pis/src/m/x.py"))
  end)
  it("finds venv and pinned tools, nil when missing", function()
    assert.equals(d .. "/pis/.venv", py.venv(d .. "/pis"))
    assert.is_nil(py.venv(d .. "/nope"))
    assert.equals(d .. "/pis/.venv/bin/ty", py.tool(d .. "/pis", "ty"))
    assert.is_nil(py.tool(d .. "/pts", "ty"))
  end)
  it("warns once for a missing tool", function()
    assert.is_false(py.missing_tool_warned(d .. "/pts", "ty"))
    assert.is_true(py.missing_tool_warned(d .. "/pts", "ty"))
    assert.equals(1, #notes)
    assert.matches("ty not in .*/pts/%.venv", notes[1].msg)
    assert.is_false(py.missing_tool_warned(d .. "/pts", "ruff"))
    assert.equals(2, #notes)
  end)
  it("calls back asynchronously when the venv already exists", function()
    local got
    py.ensure(d .. "/pis", function(ok) got = ok end)
    assert.is_nil(got)
    vim.wait(1000, function() return got ~= nil end)
    assert.is_true(got)
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
  it("does not retry a failed sync until reset, with one error notification", function()
    vim.fn.mkdir(d .. "/bad", "p"); py.sync_cmd = { "sh", "-c", "echo boom >&2; exit 1" }
    local r1, r2
    py.ensure(d .. "/bad", function(ok, err) r1 = { ok, err } end); vim.wait(2000, function() return r1 end)
    assert.is_false(r1[1]); assert.matches("boom", r1[2])
    py.sync_cmd = { "sh", "-c", "exit 0" }
    py.ensure(d .. "/bad", function(ok, err) r2 = { ok, err } end); vim.wait(2000, function() return r2 end)
    assert.is_false(r2[1]); assert.matches("CcPyenvSync", r2[2])
    local errors = vim.tbl_filter(function(n) return n.level == vim.log.levels.ERROR end, notes)
    assert.equals(1, #errors)
    assert.matches("boom", errors[1].msg)
  end)
  it(":CcPyenvSync clears the failed flag and retries", function()
    vim.fn.mkdir(d .. "/bad2/src", "p"); vim.fn.writefile({ "[project]" }, d .. "/bad2/pyproject.toml")
    py.sync_cmd = { "sh", "-c", "echo boom >&2; exit 1" }
    local r1; py.ensure(d .. "/bad2", function(ok) r1 = ok end); vim.wait(2000, function() return r1 ~= nil end)
    assert.is_false(r1)
    py.sync_cmd = { "sh", "-c", "mkdir -p .venv/bin; touch .venv/bin/python; chmod +x .venv/bin/python" }
    vim.cmd.edit(d .. "/bad2/src/x.py")
    vim.cmd("CcPyenvSync")
    assert.is_true(vim.wait(3000, function() return py.venv(d .. "/bad2") ~= nil end))
    vim.cmd("silent! %bwipeout!")
  end)
  it("commands notify instead of erroring outside a package", function()
    local out = h.tmpdir()
    vim.cmd.edit(out .. "/loose.txt")
    vim.cmd("CcPyenvSync"); vim.cmd("CcPyenvInfo")
    assert.equals(2, #notes)
    assert.matches("not in a Python package", notes[1].msg)
    vim.cmd("silent! %bwipeout!")
  end)
  it(":CcPyenvInfo reports root, venv and tools", function()
    vim.cmd.edit(d .. "/pis/src/m/x.py")
    vim.cmd("CcPyenvInfo")
    assert.matches(d .. "/pis/.venv/bin/ty", notes[#notes].msg, 1, true)
    assert.matches(d .. "/pis", notes[#notes].msg, 1, true)
    vim.cmd("silent! %bwipeout!")
  end)
end)
