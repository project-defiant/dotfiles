-- YAML/TOML/JSON/Markdown come from the LazyVim extras listed in lazyvim.json.
-- Here: map the otter config schema onto the pipeline config files, on top of SchemaStore.

local OTTER_SCHEMA = "https://raw.githubusercontent.com/opentargets/otter/refs/heads/main/.vscode/config-schema.json"

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      local yamlls = opts.servers.yamlls or {}
      opts.servers.yamlls = yamlls
      -- the extra's before_init merges SchemaStore into settings.yaml.schemas at client start
      -- (deep "force" over what is already there), so ours is kept alongside it.
      yamlls.settings = vim.tbl_deep_extend("force", yamlls.settings or {}, {
        yaml = { schemas = { [OTTER_SCHEMA] = { "**/pis/config.yaml", "**/pts/config.yaml" } } },
      })
    end,
  },
}
