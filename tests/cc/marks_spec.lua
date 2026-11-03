local h, m = require("tests.helpers"), require("cc.marks")
describe("cc.marks", function()
  local p, fa
  before_each(function()
    p = h.bare_project(); fa = p.wt["feat/a"]; m.file = h.tmpdir() .. "/marks.json"
    vim.fn.writefile({ "x" }, fa .. "/pis/new.py")
  end)
  after_each(h.cleanup)

  it("marks, persists and detects staleness", function()
    assert.equals("todo", m.status(fa, "feat/a", "pis/new.py"))
    assert.is_true(m.toggle(fa, "feat/a", "pis/new.py"))
    package.loaded["cc.marks"] = nil; local m2 = require("cc.marks"); m2.file = m.file
    assert.equals("reviewed", m2.status(fa, "feat/a", "pis/new.py"))
    vim.fn.writefile({ "y" }, fa .. "/pis/new.py")
    assert.equals("stale", m2.status(fa, "feat/a", "pis/new.py"))
  end)
  it("lists progress over changed files", function()
    local base = h.git(fa, { "rev-parse", "HEAD" })
    assert.same({ { rel = "pis/new.py", status = "todo" } }, m.progress(fa, "feat/a", base))
  end)
  it("toggles off again", function()
    assert.is_true(m.toggle(fa, "feat/a", "pis/new.py"))
    assert.is_false(m.toggle(fa, "feat/a", "pis/new.py"))
    assert.equals("todo", m.status(fa, "feat/a", "pis/new.py"))
  end)
  it("keeps marks per branch", function()
    m.toggle(fa, "feat/a", "pis/new.py")
    assert.equals("todo", m.status(fa, "other", "pis/new.py"))
  end)
  it("marks deleted files and includes them in progress", function()
    local base = h.git(fa, { "rev-parse", "HEAD" })
    vim.fn.delete(fa .. "/pis/pyproject.toml")
    assert.is_true(m.toggle(fa, "feat/a", "pis/pyproject.toml"))
    assert.equals("reviewed", m.status(fa, "feat/a", "pis/pyproject.toml"))
    assert.same({
      { rel = "pis/new.py", status = "todo" },
      { rel = "pis/pyproject.toml", status = "reviewed" },
    }, m.progress(fa, "feat/a", base))
  end)
  it("treats a corrupt marks file as empty, notifying once, without throwing", function()
    vim.fn.writefile({ "{not json" }, m.file)
    local notes = {}
    local orig = vim.notify
    vim.notify = function(msg) notes[#notes + 1] = msg end
    local ok, st = pcall(m.status, fa, "feat/a", "pis/new.py")
    pcall(m.status, fa, "feat/a", "pis/new.py")
    vim.notify = orig
    assert.is_true(ok); assert.equals("todo", st)
    assert.equals(1, #notes)
    assert.is_true(m.toggle(fa, "feat/a", "pis/new.py"))
  end)
end)
