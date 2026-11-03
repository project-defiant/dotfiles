return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      { "<leader>gvv", function() require("cc.review").open_branch() end, desc = "Branch diff vs base" },
      { "<leader>gvc", function() require("cc.review").open_commits() end, desc = "Branch commits" },
      { "<leader>gvb", function() require("cc.review").pick_base() end, desc = "Pick review base" },
      { "<leader>gvm", function() require("cc.marks").toggle_current() end, desc = "Toggle file reviewed" },
      { "<leader>gvp", function() require("cc.marks").pick_progress() end, desc = "Review progress" },
      { "<leader>gvq", "<cmd>DiffviewClose<cr>", desc = "Close review" },
    },
    opts = {
      enhanced_diff_hl = true,
      file_panel = { listing_style = "tree" },
      keymaps = {
        view = { { "n", "m", function() require("cc.marks").toggle_current() end, { desc = "Toggle file reviewed" } } },
        file_panel = { { "n", "m", function() require("cc.marks").toggle_current() end, { desc = "Toggle file reviewed" } } },
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>gv", group = "review" } } },
  },
}
