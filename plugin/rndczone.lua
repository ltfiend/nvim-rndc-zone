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

function M.setup(user_config)
	user_config = user_config or {}
	for k, v in pairs(user_config) do
		M.config[k] = v
	end
end
