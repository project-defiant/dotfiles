return require('packer').startup(function(use)
	-- Packer can manage itself
	use('wbthomason/packer.nvim')
	-- Collection of common configurations for the Nvim LSP client
	use("neovim/nvim-lspconfig")
	-- Visualize lsp progress
	use({
		"j-hui/fidget.nvim",
		config = function()
			require("fidget").setup()
		end
	})
	-- Autocompletion framework
	use("hrsh7th/nvim-cmp")
	use({
		-- cmp LSP completion
		"hrsh7th/cmp-nvim-lsp",
		-- cmp Snippet completion
		"hrsh7th/cmp-vsnip",
		-- cmp Path completion
		"hrsh7th/cmp-path",
		"hrsh7th/cmp-buffer",
		after = { "hrsh7th/nvim-cmp" },
		requires = { "hrsh7th/nvim-cmp" },
	})
	-- See hrsh7th other plugins for more great completion sources!
	-- Snippet engine
	use('hrsh7th/vim-vsnip')
	-- Adds extra functionality over rust analyzer
	use("simrat39/rust-tools.nvim")

	-- Optional
	use("nvim-lua/popup.nvim")
	use("nvim-lua/plenary.nvim")
	use("nvim-telescope/telescope.nvim")

	-- Some color scheme other then default
	use("arcticicestudio/nord-vim")
	-- nvim tree
	use('nvim-tree/nvim-web-devicons')
	use('nvim-tree/nvim-tree.lua')
	use {
		'nvim-treesitter/nvim-treesitter',
		run = ':TSUpdate'
	}
	--use {
	--		'glepnir/lspsaga.nvim',
	-- fix version of the saga to v0.2.4, 0.2.5 has breaking changes
	--		commit = "e018bb0c6a9c355fa882dc6b278abb30f776e8a0"
	--	}
	use('mhartington/oceanic-next')
	use('psf/black')
	use { 'nvim-lualine/lualine.nvim',
		requires = { 'kyazdani42/nvim-web-devicons', opt = true } }
	use("tpope/vim-commentary")
	use { 'glepnir/dashboard-nvim' }
	-- install without yarn or npm
	use({
		"iamcco/markdown-preview.nvim",
		run = function() vim.fn["mkdp#util#install"]() end,
	})
	use("jose-elias-alvarez/null-ls.nvim")
	use('jalvesaq/Nvim-R')
	use('gaalcaras/ncm-R')
	use('ncm2/ncm2')
	use('jaredgorski/spacecamp')
	use('LukeGoodsell/nextflow-vim')
	use { 'romgrk/barbar.nvim', wants = 'nvim-web-devicons' }
	use({
		'rose-pine/neovim',
		as = 'rose-pine',
		config = function()
			vim.cmd('colorscheme rose-pine')
		end
	})
	use { 'sbdchd/neoformat' } -- prettier
	use { 'heavenshell/vim-jsdoc' }
	use { 'brenoprata10/nvim-highlight-colors' }
end)
