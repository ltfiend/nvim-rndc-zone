# nvim-rndczone

Neovim plugin to edit BIND DNS zones using `rndc showzone` and commit changes with `rndc modzone`.

## Features

- Open zone config from `rndc showzone <zone>` in a buffer
- Edit zone config in standard named.conf style
- Commit changes on `:w` or with `:RNDZCommit` command

## Installation

Using lazy.nvim, add this to your plugin specs:

```lua
{
  "ltfiend/nvim-rndczone",
  lazy = true,
  cmd = { "RNDZEdit", "RNDZCommit" },
}

## Usage

  ### Begin Editing a Zone Definition

  `:RNDZEdit <domain name>`

  ### Commit zone definition using modzone

  `:RNDZCommit`

  `:wq!`  
