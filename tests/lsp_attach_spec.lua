-- Verifies the optional named.conf docs LSP attaches to a zone-config buffer
-- and resolves hover. Requires the sibling nvim-named-conf repo on the
-- runtimepath (added by tests/minimal_init.lua).
local rndczone = require("rndczone")

local function zone_buffer()
	local buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch (no swap)
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("filetype", "conf", { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		'zone "test.example" {',
		"	type primary;",
		'	file "test.example.zone";',
		"	allow-transfer { key \"xfer\"; };",
		"};",
	})
	return buf
end

local have_named_conf = pcall(require, "named-conf")

describe("rndczone LSP attach", function()
	it("requires the optional nvim-named-conf to be on the runtimepath", function()
		assert.is_true(have_named_conf, "nvim-named-conf sibling repo not found on rtp")
	end)

	it("attaches a named-conf client to a zone-config buffer", function()
		local buf = zone_buffer()
		rndczone._attach_lsp(buf)
		local clients = vim.lsp.get_clients({ bufnr = buf, name = "named-conf" })
		assert.equals(1, #clients)
	end)

	it("resolves hover docs for a zone statement keyword", function()
		local buf = zone_buffer()
		rndczone._attach_lsp(buf)
		local nc = require("named-conf")
		-- row 1 (0-indexed) is `	type primary;`; hover over `type`.
		local line = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1]
		local col = (line:find("type")) - 1
		local md = nc.hover_markdown(buf, 1, col)
		assert.is_not_nil(md)
		assert.is_true(md:find("type", 1, true) ~= nil)
	end)

	it("does nothing when config.lsp is false", function()
		local prev = rndczone.config.lsp
		rndczone.config.lsp = false
		local buf = zone_buffer()
		rndczone._attach_lsp(buf)
		rndczone.config.lsp = prev
		local clients = vim.lsp.get_clients({ bufnr = buf, name = "named-conf" })
		assert.equals(0, #clients)
	end)
end)
