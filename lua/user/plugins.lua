-- packer setup 
return require('packer').startup(function(use)

	use 'wbthomason/packer.nvim'  -- just a packer manager
	use 'neovim/nvim-lspconfig'   -- lsp
	use 'folke/tokyonight.nvim'   -- color scheme
	use 'kyazdani42/nvim-web-devicons'
	use { 
		'nvim-lualine/lualine.nvim', 
		requires = { 
			'kyazdani42/nvim-web-devicons', 
			opt = true }
		}   -- status line
	use {"akinsho/toggleterm.nvim", tag = 'v2.*', config = function()
end}
 end)
