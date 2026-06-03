# nvim-rndczone

Neovim plugin to edit BIND DNS zones using `rndc showzone` and commit changes with `rndc modzone`.

## Features

- List all zones maintained on the server and present in a picker
- Open zone config from `rndc showzone <zone>` in a buffer
- Edit zone config in standard named.conf style
- Commit changes on `:w` or with `:RNDZCommit` command
- **Optional** inline docs — hover (`K`) and completion for zone statements
  (`type`, `file`, `allow-transfer`, `masters`/`primaries`, `update-policy`, …)
  when [`nvim-named-conf`](https://github.com/ltfiend/nvim-named-conf) is
  installed. See [Documentation hover & completion](#documentation-hover--completion).

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

## Documentation hover & completion

A zone block fetched by `rndc showzone` is named.conf syntax, so the in-process
documentation LSP from [`nvim-named-conf`](https://github.com/ltfiend/nvim-named-conf)
can describe it. When that plugin is installed, every zone buffer opened with
`:RNDZEdit` automatically gets:

- **`K`** — hover docs for the statement/value under the cursor.
- **completion** — documented zone statements and values (via the attached LSP
  client; works with your existing completion engine or omnifunc).
- **`:RNDZDocs`** — show the docs popup directly.

This is entirely optional: if `nvim-named-conf` is not installed, zone editing
works exactly as before and a one-time notice is shown.

```lua
return {
  "ltfiend/nvim-rndc-zone",
  dependencies = { "ltfiend/nvim-named-conf" }, -- optional, enables hover/completion
  config = function()
    require("rndczone").setup({
      bind_ip = "192.168.1.1",
      catalog_domain = "catalog.example",
      tsigkey = "/etc/bind/tsig.key",
      -- lsp = false,  -- set to disable the docs LSP even if named-conf is present
    })
  end,
}
```

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

