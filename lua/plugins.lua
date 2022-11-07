
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
	  use{
        'nvim-treesitter/nvim-treesitter',
        run = ':TSUpdate'
    }
		use('glepnir/lspsaga.nvim')
		use('mhartington/oceanic-next')
		use('psf/black')
	end)
