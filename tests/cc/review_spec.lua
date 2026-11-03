local h, r = require("tests.helpers"), require("cc.review")
describe("cc.review.base", function()
  local p
  before_each(function() p = h.bare_project() end)
  after_each(h.cleanup)

  it("defaults to merge-base with origin/main", function()
    h.with_origin(p)
    h.git(p.root, { "worktree", "add", "-b", "feat/c", p.root .. "/feat/c", "origin/main" })
    local fc = p.root .. "/feat/c"
    h.git(fc, { "commit", "--allow-empty", "-m", "c1" })
    local expected = h.git(fc, { "merge-base", "origin/main", "HEAD" })
    assert.are_not.equals(h.git(fc, { "merge-base", "main", "HEAD" }), expected)
    assert.equals(expected, (r.base(fc)))
  end)
  it("falls back to local main without a remote", function()
    local fa = p.wt["feat/a"]
    assert.equals(h.git(fa, { "merge-base", "main", "HEAD" }), (r.base(fa)))
  end)
  it("honours a stacked-branch override", function()
    local fa = p.wt["feat/a"]
    h.git(fa, { "commit", "--allow-empty", "-m", "a1" })
    h.git(p.root, { "worktree", "add", "-b", "feat/b", p.root .. "/feat/b", "feat/a" })
    local fb = p.root .. "/feat/b"
    r.set_override(fb, "feat/a")
    assert.equals(h.git(fb, { "rev-parse", "feat/a" }), (r.base(fb)))
  end)
  it("errors clearly when no main exists", function()
    local q = h.bare_project({ main = "trunk" })
    local sha, err = r.base(q.wt["feat/a"])
    assert.is_nil(sha); assert.matches("no base", err)
  end)
end)
