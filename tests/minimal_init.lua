-- Minimal init for running tests
-- Add plenary to runtimepath (assumes installed via package manager)
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 1 then
	vim.opt.runtimepath:append(plenary_path)
end

-- Add the plugin itself to runtimepath
local plugin_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:append(plugin_path)

-- Add the sibling nvim-named-conf repo (optional docs LSP dependency) so the
-- LSP-attach spec can resolve `require('named-conf')`. Both repos live under
-- ~/Git, which the Makefile mounts into the test container.
local sibling = vim.fn.fnamemodify(plugin_path, ":h") .. "/nvim-named-conf"
if vim.fn.isdirectory(sibling) == 1 then
	vim.opt.runtimepath:append(sibling)
end

-- No swap/shada in headless runs (state dir may be read-only in the container).
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"

-- Load plenary
vim.cmd("runtime plugin/plenary.vim")
