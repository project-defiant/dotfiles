require 'lspconfig'.bashls.setup {}
require 'lspconfig'.dockerls.setup {}
require 'lspconfig'.dotls.setup {}
require 'lspconfig'.emmet_ls.setup {}
require 'lspconfig'.eslint.setup {}
--Enable (broadcasting) snippet capability for completion
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

require 'lspconfig'.html.setup {
	capabilities = capabilities,
}
require 'lspconfig'.jsonls.setup {
	capabilities = capabilities,
}
require 'lspconfig'.ltex.setup {}
require 'lspconfig'.marksman.setup {}
require 'lspconfig'.metals.setup {}
require 'lspconfig'.tsserver.setup {}
require 'lspconfig'.vimls.setup {}
require 'lspconfig'.jsonnet_ls.setup {}

-- lua lsp
require 'lspconfig'.sumneko_lua.setup {
	settings = {
		Lua = {
			runtime = {
				-- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
				version = 'LuaJIT',
			},
			diagnostics = {
				-- Get the language server to recognize the `vim` global
				globals = { 'vim' },
			},
			workspace = {
				-- Make the server aware of Neovim runtime files
				library = vim.api.nvim_get_runtime_file("", true),
			},
			-- Do not send telemetry data containing a randomized but unique identifier
			telemetry = {
				enable = false,
			},
		},
	},
}

--python lsp

require 'lspconfig'.pyright.setup {}
--require 'lspconfig'.jedi_language_server.setup {}
--Enable (broadcasting) snippet capability for completion
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
-- require'lspconfig'.pylsp.setup{
--   settings = {
--     pylsp = {
--       plugins = {
--         pycodestyle = {
--           ignore = {'W391'},
--           maxLineLength = 100
--         }
--       }
--     }
--   }
-- }
--
--
-- r lsp

require 'lspconfig'.r_language_server.setup {}
