return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      { "<leader>gvv", function() require("cc.review").open_branch() end, desc = "Branch diff vs base" },
      { "<leader>gvc", function() require("cc.review").open_commits() end, desc = "Branch commits" },
      { "<leader>gvb", function() require("cc.review").pick_base() end, desc = "Pick review base" },
      { "<leader>gvq", "<cmd>DiffviewClose<cr>", desc = "Close review" },
    },
    opts = {
      enhanced_diff_hl = true,
      file_panel = { listing_style = "tree" },
    },
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>gv", group = "review" } } },
  },
}
