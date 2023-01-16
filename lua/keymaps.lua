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


-- Commentary
keymap("n", "<C-_>", ":Commentary<CR>", opts)


-- Buffers
-- Move t:wqo previous/next
keymap('n', '<A-,>', '<Cmd>BufferPrevious<CR>', opts)
keymap('n', '<A-.>', '<Cmd>BufferNext<CR>', opts)
-- Re-order to previous/next
keymap('n', '<A-<>', '<Cmd>BufferMovePrevious<CR>', opts)
keymap('n', '<A->>', '<Cmd>BufferMoveNext<CR>', opts)
-- Goto buffer in position...
keymap('n', '<A-1>', '<Cmd>BufferGoto 1<CR>', opts)
keymap('n', '<A-2>', '<Cmd>BufferGoto 2<CR>', opts)
keymap('n', '<A-3>', '<Cmd>BufferGoto 3<CR>', opts)
keymap('n', '<A-4>', '<Cmd>BufferGoto 4<CR>', opts)
keymap('n', '<A-5>', '<Cmd>BufferGoto 5<CR>', opts)
keymap('n', '<A-6>', '<Cmd>BufferGoto 6<CR>', opts)
keymap('n', '<A-7>', '<Cmd>BufferGoto 7<CR>', opts)
keymap('n', '<A-8>', '<Cmd>BufferGoto 8<CR>', opts)
keymap('n', '<A-9>', '<Cmd>BufferGoto 9<CR>', opts)
keymap('n', '<A-0>', '<Cmd>BufferLast<CR>', opts)
-- Pin/unpin buffer
keymap('n', '<A-p>', '<Cmd>BufferPin<CR>', opts)
-- Close buffer
keymap('n', '<A-c>', '<Cmd>BufferClose<CR>', opts)
-- Wipeout buffer
--                 :BufferWipeout
-- Close commands
--                 :BufferCloseAllButCurrent
--                 :BufferCloseAllButPinned
--                 :BufferCloseAllButCurrentOrPinned
--                 :BufferCloseBuffersLeft
--                 :BufferCloseBuffersRight
-- Magic buffer-picking mode
keymap('n', '<C-p>', '<Cmd>BufferPick<CR>', opts)
-- Sort automatically by...
keymap('n', '<Space>bb', '<Cmd>BufferOrderByBufferNumber<CR>', opts)
keymap('n', '<Space>bd', '<Cmd>BufferOrderByDirectory<CR>', opts)
keymap('n', '<Space>bl', '<Cmd>BufferOrderByLanguage<CR>', opts)
keymap('n', '<Space>bw', '<Cmd>BufferOrderByWindowNumber<CR>', opts)

-- Other:
-- :BarbarEnable - enables barbar (enabled by default)
-- :BarbarDisable - very bad command, should never be used
