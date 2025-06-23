local M = {}

local api = vim.api

-- parse rndc showzone output to zone block
-- example input line: zone "example.com" {
-- parse the text and reconstruct standard zone block format
function M.parse_showzone_output(output)
	-- output is string with multiple lines
	-- We'll keep all lines from the first "zone" line until matching "};"
	local lines = {}
	local zone_block = {}
	local inside = false
	for line in output:gmatch("[^\r\n]+") do
		if line:match('^zone%s+".-"%s+{') then
			inside = true
		end
		if inside then
			table.insert(zone_block, line)
			if line:match("^};") then
				break
			end
		end
	end

	-- The output of rndc showzone is often multiline with indentation but may have some extra data
	-- We'll convert to a typical named.conf zone block by cleaning extra whitespace and formatting
	-- For simplicity, join as is but remove any trailing spaces and extra blank lines
	-- Optionally fix indentation - here we just return as is
	return table.concat(zone_block, "\n")
end

-- Run a shell command and return stdout (or error)
local function exec_cmd(cmd)
	local handle = io.popen(cmd)
	if not handle then
		return nil, "Failed to run command"
	end
	local result = handle:read("*a")
	local success, _, code = handle:close()
	if success or code == 0 then
		return result, nil
	else
		return nil, "Command failed with exit code " .. tostring(code)
	end
end

-- Load zone config into buffer for editing
function M.edit_zone(zone)
	if not zone or zone == "" then
		api.nvim_err_writeln("Zone name required")
		return
	end

	local cmd = "rndc showzone " .. zone
	local out, err = exec_cmd(cmd)
	if err then
		api.nvim_err_writeln("Failed to run rndc showzone: " .. err)
		return
	end
	if not out or out == "" then
		api.nvim_err_writeln("No output from rndc showzone")
		return
	end

	local zone_block = M.parse_showzone_output(out)

	-- Open new buffer for editing zone config
	api.nvim_command("enew") -- new empty buffer
	local buf = api.nvim_get_current_buf()

	api.nvim_buf_set_option(buf, "buftype", "")
	api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	api.nvim_buf_set_option(buf, "swapfile", false)
	api.nvim_buf_set_name(buf, "rndc_zone:" .. zone)

	-- Store zone name in buffer variable for later use
	api.nvim_buf_set_var(buf, "rndczone_zone", zone)

	-- Insert zone block text
	api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(zone_block, "\n"))

	-- Set filetype to "conf" for syntax highlight
	api.nvim_buf_set_option(buf, "filetype", "conf")

	-- Set autocmd on BufWritePre to commit changes
	api.nvim_create_autocmd("BufWritePost", {
		buffer = buf,
		callback = function()
			M.commit_zone(buf)
		end,
	})
end

-- Commit zone changes with rndc modzone
function M.commit_zone(buf)
	buf = buf or api.nvim_get_current_buf()
	local ok, zone = pcall(api.nvim_buf_get_var, buf, "rndczone_zone")
	if not ok or not zone then
		api.nvim_err_writeln("Not a rndc zone buffer")
		return
	end

	-- Get buffer lines as zone config
	local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
	local tempname = os.tmpname()

	-- Write buffer contents to temp file
	local f, err = io.open(tempname, "w")
	if not f then
		api.nvim_err_writeln("Failed to open temp file: " .. err)
		return
	end
	f:write(table.concat(lines, "\n"))
	f:close()

	-- Run rndc modzone <zone> < temp_file
	local cmd = string.format("rndc modzone %s < %s", zone, tempname)
	local handle = io.popen(cmd)
	if not handle then
		api.nvim_err_writeln("Failed to run rndc modzone command")
		os.remove(tempname)
		return
	end
	local result = handle:read("*a")
	local success, _, code = handle:close()

	os.remove(tempname)

	if success or code == 0 then
		print("rndc modzone committed successfully for zone: " .. zone)
	else
		api.nvim_err_writeln("rndc modzone failed: " .. result)
	end
end

return M
