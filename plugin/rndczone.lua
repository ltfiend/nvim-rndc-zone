local rndczone = require("rndczone")

vim.api.nvim_create_user_command("RNDZEdit", function(opts)
	rndczone.edit_zone(opts.args)
end, { nargs = 1, complete = "file" })

vim.api.nvim_create_user_command("RNDZCommit", function()
	local buf = vim.api.nvim_get_current_buf()
	rndczone.commit_zone(buf)
end, { nargs = 0 })
