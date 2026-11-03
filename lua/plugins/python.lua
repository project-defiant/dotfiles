-- ty + ruff come from each uv package's pinned .venv (cc.pyenv), never from Mason or PATH.

---@param name string server name, also the binary name in .venv/bin
local function venv_server(name)
  return {
    mason = false,
    root_dir = function(bufnr, on_dir)
      if vim.bo[bufnr].buftype ~= "" then
        return
      end
      local pyenv = require("cc.pyenv")
      local r = pyenv.root(vim.api.nvim_buf_get_name(bufnr))
      if not r then
        return
      end
      pyenv.ensure(r, function(ok)
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
    opts = {
      adapters = {
        ["neotest-python"] = {
          runner = "pytest",
          python = function(root)
            return { "uv", "run", "--frozen", "--project", root, "python" }
          end,
        },
      },
    },
  },
}
