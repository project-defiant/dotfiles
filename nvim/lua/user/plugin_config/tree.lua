
require("nvim-tree").setup()


local opts = { noremap = true, silent = true}
-- local telescope = require("telescope.builtin")
local keymap = vim.api.nvim_set_keymap
-- telescope keymaps
--
keymap("n", "<Leader>fp", ":NvimTreeToggle <CR>", opts)


