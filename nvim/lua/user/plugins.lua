
-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  return
end

-- Have packer use a popup window
packer.init {
	display = {
	  open_fn = function()
			return require("packer.util").float { border = "rounded" }
		end,
  	},
}


packer.startup(function(use)

	use 'wbthomason/packer.nvim'  -- just a packer manager
	use 'nvim-lua/popup.nvim'
	use 'nvim-lua/plenary.nvim'
	use 'neovim/nvim-lspconfig'   -- lsp
	use 'folke/tokyonight.nvim'   -- color scheme
	use 'kyazdani42/nvim-web-devicons'
	use 'kyazdani42/nvim-tree.lua'
	use { "windwp/nvim-autopairs", config = function() require("nvim-autopairs").setup {} end } -- autocompletion of brackets & quotes
	use 'hrsh7th/nvim-cmp' -- autocompletion
	use 'hrsh7th/cmp-buffer'
	use 'hrsh7th/cmp-path'
	use 'hrsh7th/cmp-cmdline'
	use 'saadparwaiz1/cmp_luasnip'
	use 'L3MON4D3/LuaSnip'
	use 'rafamadriz/friendly-snippets'
	use { 'nvim-treesitter/nvim-treesitter',    run = function() require('nvim-treesitter.install').update({ with_sync = true }) end, }
	use { 'nvim-telescope/telescope-fzf-native.nvim', run = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build" } 
	use { 'nvim-telescope/telescope.nvim', tag = '0.1.0' }
	use { 'nvim-lualine/lualine.nvim', requires = { 'kyazdani42/nvim-web-devicons', opt = true } }   -- status line
	use { "akinsho/toggleterm.nvim", tag = 'v2.*', config = function() end }
end)


 -- TODO: Try
 -- vim-dispatch
 -- markdown-preview
 -- vim-closer
 --
