-- Minimal init for running tests
-- Add plenary to runtimepath (assumes installed via package manager)
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 1 then
	vim.opt.runtimepath:append(plenary_path)
end

-- Add the plugin itself to runtimepath
local plugin_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:append(plugin_path)

-- Load plenary
vim.cmd("runtime plugin/plenary.vim")
