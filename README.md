# nvim-rndczone

Neovim plugin to edit BIND DNS zones using `rndc showzone` and commit changes with `rndc modzone`.

## Features

- List all zones maintained on the server and present in a picker
- Open zone config from `rndc showzone <zone>` in a buffer
- Edit zone config in standard named.conf style
- Commit changes on `:w` or with `:RNDZCommit` command

## Installation

Using lazy.nvim, add this to your plugins/nvim-rndc-zone.lua file:

```
return {
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
}
```

## Usage

### Begin Editing a Zone Definition

  `:RNDCList` - Select domain from list for editing

  `:RNDZEdit <domain name>` - Edit a specific domain

### Commit zone definition using modzone

  `:RNDZCommit` - Commit zone without closing nvim

  `:q` - Commit and close nvim

## Keymaps

Add to keymaps.lua:

```
require("which-key").add({
        -- VISUAL mode mappings
        -- s, x, v modes are handled the same way by which_key
        {
                mode = { "n" },
                nowait = true,
                remap = false,
                { "<C-r>l", "<cmd>RNDZList<cr>", desc = "RNDZ List" },
                { "<C-r>e", "<cmd>RNDZEdit<cr>", desc = "RNDZ Edit" },
                { "<C-r>c", "<cmd>RNDZCommit<cr>", desc = "RNDZ Commit" },
        },
})
```

