# nvim-rndc-zone

A simple Neovim plugin to edit BIND DNS zones by fetching zone config via `rndc showzone`,
allowing inline editing, and committing changes back with `rndc modzone` automatically on save.

## Features

- `:EditZone <zone>` opens the zone config in a new tab for editing.
- Saves changes with `:w` automatically call `rndc modzone <zone> <file>`.
- Manual commit available with `:CommitZone`.
- Minimal dependencies; works with Neovim 0.7+.

## Installation

Use your favorite plugin manager:

### Packer

```lua
use 'your-github-username/nvim-rndc-zone'

