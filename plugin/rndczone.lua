local rndczone = require("rndczone")

vim.api.nvim_create_user_command("RNDZEdit", function(opts)
	rndczone.edit_zone(opts.args)
end, { nargs = 1, complete = "file" })

vim.api.nvim_create_user_command("RNDZCommit", function()
	local buf = vim.api.nvim_get_current_buf()
	rndczone.commit_zone(buf)
end, { nargs = 0 })

vim.api.nvim_create_user_command("RNDZList", function()
	require("rndczone").list_zones()
end, {})

-- Show named.conf docs for the symbol under the cursor (requires the optional
-- nvim-named-conf plugin). No-op with a hint if it isn't installed.
vim.api.nvim_create_user_command("RNDZDocs", function()
	local ok, nc = pcall(require, "named-conf")
	if ok and type(nc.docs) == "function" then
		nc.docs()
	else
		vim.notify("[rndczone] :RNDZDocs needs ltfiend/nvim-named-conf installed", vim.log.levels.INFO)
	end
end, {})
