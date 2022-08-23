require("user.options")
require("user.keymaps")
require("user.plugins")
require("user.plugin_config.colorscheme")
require("user.plugin_config.statusbar")
require("user.plugin_config.terminal")
require("user.plugin_config.cmp")
require("user.lsp")
require("user.plugin_config.telescope")

require'lspconfig'.pyright.setup{}