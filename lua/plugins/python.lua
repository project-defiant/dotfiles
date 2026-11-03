-- ty + ruff come from each uv package's pinned .venv (cc.pyenv), never from Mason or PATH.

---@param name string server name, also the binary name in .venv/bin
local function venv_server(name)
  return {
    mason = false,
    root_dir = function(bufnr, on_dir)
      local fname = vim.api.nvim_buf_get_name(bufnr)
      -- unnamed buffers must not resolve a root from the cwd
      if vim.bo[bufnr].buftype ~= "" or fname == "" then
        return
      end
      local pyenv = require("cc.pyenv")
      local r = pyenv.root(fname)
      if not r then
        return
      end
      pyenv.ensure(r, function(ok)
        -- the buffer may have been wiped (e.g. worktree switch) while uv sync ran
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end
        if ok and pyenv.tool(r, name) then
          on_dir(r)
        elseif ok then
          pyenv.missing_tool_warned(r, name)
        end
      end)
    end,
    cmd = function(dispatchers, config)
      local pyenv = require("cc.pyenv")
      return vim.lsp.rpc.start(
        { pyenv.tool(config.root_dir, name), "server" },
        dispatchers,
        { cwd = config.root_dir, env = config.cmd_env }
      )
    end,
  }
end

-- Neovim never stops a client that has lost its buffers: stop ty/ruff from other worktrees on switch.
vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("cc_pyenv_lsp", { clear = true }),
  pattern = "CcWorktreeChanged",
  callback = function(ev)
    require("cc.pyenv").stop_foreign_clients(ev.data.path)
  end,
})

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = { enabled = false },
        basedpyright = { enabled = false },
        ty = venv_server("ty"),
        ruff = venv_server("ruff"),
      },
    },
  },
  { "linux-cultist/venv-selector.nvim", enabled = false },
  {
    "stevearc/conform.nvim",
    opts = {
      -- no conform formatter for python: fall back to the ruff LSP client (pinned binary)
      formatters_by_ft = { python = {} },
      default_format_opts = { lsp_format = "fallback" },
    },
  },
  {
    "nvim-neotest/neotest",
    opts = function(_, opts)
      -- replace LazyVim's adapter with one that runs pytest via uv from the package root
      opts.adapters = opts.adapters or {}
      opts.adapters["neotest-python"] = false
      table.insert(opts.adapters, require("cc.pyenv").neotest_adapter())
    end,
  },
}
