# PROJECT DEFIANT - DOTFILES

This repo is for self use. It contains my configuration files for tools that I use day to day.

## nvim

The editor of choise is neovim, for which I have created config, that can be easly linked.

Prerequisitories are:

- [x] Packer - see (repo)[https://github.com/wbthomason/packer.nvim] for the installation steps
- [x] neovim v0.8
- [x] list of nvim plugins, that are installed with `PackerInstall`


The configuration enables:
- [x] simple keymap - can be found in (here)[./lua/keymaps.lua]
- [x] IDE navigation with NvimTree
- [x] options for better code editing (mouse, nowrap, clipboard - requires `xclip`)
- [x] lsp for python & rust
- [x] treesitter for python & rust
- [x] pylint, flake8 & black integration (requires above packages in venv)
- [x] ocean style
- [ ] file speific commenting
- [ ] enhanced python development
- [ ] R integration
- [ ] go integration
- [ ] js integration
- [ ] c++ integration
