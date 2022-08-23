local status_ok, _ = pcall(require("lspconfig"))
if not status_ok then
	return
end




--lsp_installer.on_server_ready(function(server)
--	local opts = {
--		on_attach = require('user.lsp.handlers').on_attach,
--		capabilities = require('user.lsp.handlers').capabilities,
--	}
--
--
require'lspconfig'.pyright.setup{}
