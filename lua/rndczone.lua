local M = {}
local uv = vim.loop
local api = vim.api

local function run_cmd(cmd, callback)
	local handle
	local stdout = uv.new_pipe(false)
	local stderr = uv.new_pipe(false)
	local output = {}
	local error_output = {}

	handle = uv.spawn("sh", {
		args = { "-c", cmd },
		stdio = { nil, stdout, stderr },
	}, function(code, signal, err)
		stdout:close()
		stderr:close()
		handle:close()
		if err then
			callback(-1, "", tostring(err))
		else
			callback(code, table.concat(output), table.concat(error_output))
		end
	end)

	stdout:read_start(function(err, data)
		assert(not err, err)
		if data then
			table.insert(output, data)
		end
	end)

	stderr:read_start(function(err, data)
		assert(not err, err)
		if data then
			table.insert(error_output, data)
		end
	end)
end

local function parse_showzone_output(zone, raw)
	if raw:match('zone%s+"[^"]+"%s*{') then
		return raw
	end

	local lines = {}
	table.insert(lines, 'zone "' .. zone .. '" {')
	for line in raw:gmatch("[^\r\n]+") do
		table.insert(lines, "  " .. line)
	end
	table.insert(lines, "};")
	return table.concat(lines, "\n")
end

local current_zone = nil
local temp_file = nil

function M.edit_zone(zone)
	current_zone = zone
	run_cmd("rndc showzone " .. zone, function(code, stdout, stderr)
		if code ~= 0 then
			api.nvim_err_writeln("Error fetching zone info: " .. stderr)
			return
		end

		local zone_conf = parse_showzone_output(zone, stdout)

		local tmpname = os.tmpname()
		local f = io.open(tmpname, "w")
		f:write(zone_conf)
		f:close()
		temp_file = tmpname

		vim.schedule(function()
			api.nvim_command("tabnew " .. tmpname)
			local buf = api.nvim_get_current_buf()
			api.nvim_buf_set_var(buf, "zone_editing", true)
			api.nvim_buf_set_var(buf, "zone_name", zone)
			api.nvim_buf_set_option(buf, "filetype", "bind")
			api.nvim_out_write("Loaded zone '" .. zone .. "' for editing.\n")
		end)
	end)
end

function M.commit_zone(bufnr)
	local zone = nil
	local ok, val = pcall(api.nvim_buf_get_var, bufnr, "zone_name")
	if ok then
		zone = val
	else
		api.nvim_err_writeln("Not a zone editing buffer")
		return
	end

	local filename = api.nvim_buf_get_name(bufnr)
	run_cmd("rndc modzone " .. zone .. " " .. filename, function(code, stdout, stderr)
		if code == 0 then
			api.nvim_out_write("Zone '" .. zone .. "' updated successfully.\n")
		else
			api.nvim_err_writeln("Failed to update zone: " .. stderr)
		end
	end)
end

api.nvim_create_autocmd("BufWritePost", {
	pattern = "*",
	callback = function(args)
		local bufnr = args.buf
		local ok, val = pcall(api.nvim_buf_get_var, bufnr, "zone_editing")
		if ok and val == true then
			M.commit_zone(bufnr)
		end
	end,
})

api.nvim_create_user_command("EditZone", function(opts)
	M.edit_zone(opts.args)
end, { nargs = 1 })

api.nvim_create_user_command("CommitZone", function(opts)
	local bufnr = api.nvim_get_current_buf()
	M.commit_zone(bufnr)
end)

return M
