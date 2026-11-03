local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(config)
vim.opt.runtimepath:prepend(vim.fn.stdpath("data") .. "/lazy/plenary.nvim")
package.path = config .. "/?.lua;" .. config .. "/?/init.lua;" .. package.path
vim.opt.swapfile = false
