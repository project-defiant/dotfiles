local opts = {noremap = true, silent = true}  -- no recurse map

-- Modes
-- normal - "n"
-- insert - "i"
-- visual  - "v"
-- block - "x"
-- terminal - "t"
-- command - "c"


-- Keys
-- <C> - ctrl
-- <M> - alt
-- <esc> escape
--

local keymap = vim.api.nvim_set_keymap

-- Space as Leader
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- autocomplete brackets
keymap("i", "{",  "{}<Esc>ha", opts)
keymap("i", "[",  "[]<Esc>ha", opts)
keymap("i", "(",  "()<Esc>ha", opts)
keymap("i", "'",  "''<Esc>ha", opts)
keymap("i", '"',  '""<Esc>ha', opts)
keymap("i", "`" , "``<Esc>ha", opts)


-- toggle nvimTree
keymap("n", "<Leader>e", ":NvimTreeToggle<CR>", opts)

-- save on exit
keymap("n", "<C-s>", ":w<CR>", opts)

-- Move between tabs
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)


-- Resize the tabbs
keymap("n", "<C-Down>", ":resize -2<CR>", opts)
keymap("n", "<C-Up>", ":resize +2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Create a new empty file
keymap("n", "<Leader>n", ":new<CR>", opts)
keymap("n", "<Leader>v", ":vnew<CR>", opts)
keymap("i", "ii", "<ESC>", opts)

-- Telescope 
keymap("n", "<Leader>f", ":Telescope live_grep<CR>", opts)
keymap("n", "<Leader>p", ":Telescope find_files<CR>", opts)
