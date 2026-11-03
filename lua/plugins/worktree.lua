local ui = require("cc.worktree_ui")

local function pick()
  Snacks.picker.pick({
    title = "Worktrees",
    items = ui.items(),
    format = function(item)
      return { { item.active and "● " or "  ", "Special" }, { item.text } }
    end,
    preview = "none",
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      local ok, err = require("cc.worktree").switch(item.wt.path)
      if not ok then vim.notify(err or "switch failed", vim.log.levels.WARN) end
    end,
  })
end

return {
  {
    "folke/snacks.nvim",
    keys = { { "<leader>gw", pick, desc = "Worktrees" } },
    opts = {
      picker = {
        sources = {
          files = { config = ui.exclude_nested },
          grep = { config = ui.exclude_nested },
        },
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_b, 1, {
        ui.pointer,
        color = function()
          if not require("cc.worktree").active() then return "WarningMsg" end
        end,
      })
      vim.api.nvim_create_autocmd("User", {
        pattern = "CcWorktreeChanged",
        callback = function() require("lualine").refresh() end,
      })
    end,
  },
}
