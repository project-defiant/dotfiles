local opts = { noremap = true, silent = true}
-- local telescope = require("telescope.builtin")
local keymap = vim.api.nvim_set_keymap
-- telescope keymaps
--
keymap("n", "<Leader>ff", ":Telescope find_files hidden=true<CR>", opts)
keymap("n", "<Leader>fg", ":Telescope live_grep<CR>", opts)
keymap("n", "<Leader>fb", ":Telescope buffers<CR>", opts)
keymap("n", "<Leader>fh", ":Telescope help_tags<CR>", opts)

