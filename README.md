# nvim-rndczone

Neovim plugin to edit BIND DNS zones using `rndc showzone` and commit changes with `rndc modzone`.

## Features

- Open zone config from `rndc showzone <zone>` in a buffer
- Edit zone config in standard named.conf style
- Commit changes on `:w` or with `:RNDZCommit` command

## Installation

Using lazy.nvim, add this to your plugins/nvim-rndc-zone.lua file:

```return {
  {
    "ltfiend/nvim-rndc-zone",
    config = function()
        require("rndczone").setup({
           bind_ip = "192.168.1.1",
           catalog_domain = "catalog.example",
           tsigkey = "/etc/bind/tsig.key",
        })
   end,
  }
}```


## Usage

  ### Begin Editing a Zone Definition

  :RNDCList - select from list

  `:RNDZEdit <domain name>`

  ### Commit zone definition using modzone

  `:RNDZCommit`
