local on_attach = function(client, bufnr)
	local bufopts = { noremap = true, silent = true, buffer = bufnr }
	vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
	vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
	vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
	vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
	vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
	vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
	vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
	vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
	vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
	vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
	vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
	vim.keymap.set('n', '<space>f', function() vim.lsp.buf.format { async = true } end, bufopts)
end
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
require 'lspconfig'.tsserver.setup {
	on_attach = on_attach
}
require 'lspconfig'.vimls.setup {}
require 'lspconfig'.jsonnet_ls.setup {}

-- lua lsp
require 'lspconfig'.sumneko_lua.setup {
	on_attach = on_attach,
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

require 'lspconfig'.pyright.setup {
	on_attach = on_attach
}
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
require('lspconfig').yamlls.setup {}
require'lspconfig'.tailwindcss.setup{
	on_attach = on_attach
}




-- lsp configuration regarding keybindings
local opts = { noremap = true, silent = true }
vim.keymap.set('n', '<space>d', vim.diagnostic.open_float, opts)
