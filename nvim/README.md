# Dotfiles

The dotfiles repo is here to provide quick and easy setup for my development environment


## nvim 

I try to set up `neovim` as an IDE in exchange to `vscode` editor.

### nvim configuration structure

THe configuration structure starts from following:
```
.
├── Makefile
└── nvim
    ├── README.md
    ├── init.lua
    ├── lua
    │   └── user
    │       ├── keymaps.lua
    │       ├── options.lua
    │       ├── plugin_config
    │       │   ├── autopairs.lua
    │       │   ├── cmp.lua
    │       │   ├── colorscheme.lua
    │       │   ├── filetree.lua
    │       │   ├── lsp.lua
    │       │   ├── statusbar.lua
    │       │   ├── telescope.lua
    │       │   ├── terminal.lua
    │       │   └── tree.lua
    │       └── plugins.lua
    ├── plugin
    │   └── packer_compiled.lua
    └── tools

```

#### init.lua

The `init.lua` file contains all requirements for the `Packer` manager

#### keymaps

Inside this file I set up all keymaps specific to VIM/NVIM

#### options.lua

Here I describe all options that I use across the nvim

#### plugins_config dir

This directory holds all plugin specific configurations

#### plugins.lua

Here I add all plugins with `Packer`