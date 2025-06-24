local M = {}

local api = vim.api

-- Configuration defaults (can be overridden)
M.config = {
	bind_ip = "192.168.1.1",
	catalog_domain = "catalog.example",
}

-- Helper: trim whitespace
local function trim(s)
	return s:match("^%s*(.-)%s*$")
end

-- Pretty format zone block text for editing:
-- Add newlines after { and ;, indent nested blocks by tabs.
function M.format_zone_block_pretty(text)
	local step1 = text:gsub("{", "{\n"):gsub(";", ";\n")

	local lines = {}
	local indent_level = 0

	for line in step1:gmatch("[^\r\n]+") do
		line = trim(line)
		if line:find("^}") then
			indent_level = indent_level - 1
			if indent_level < 0 then
				indent_level = 0
			end
		end

		table.insert(lines, string.rep("\t", indent_level) .. line)

		if line:find("{") and not line:find("}") then
			indent_level = indent_level + 1
		end
	end

	return table.concat(lines, "\n")
end

-- Compact formatting for rndc modzone
function M.format_zone_block_compact(text)
	local no_indent = text:gsub("[\t ]+", " ")
	local compact = no_indent:gsub("\n%s*", " ")
	compact = compact:gsub("}%s*", "}\n")
	compact = trim(compact)
	return compact
end

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

function M.parse_showzone_output(output)
	local zone_block = {}
	local inside = false
	for line in output:gmatch("[^\r\n]+") do
		if line:match('^zone%s+".-"%s*{') then
			inside = true
		end
		if inside then
			table.insert(zone_block, line)
			if line:match("^};") then
				break
			end
		end
	end

	local raw_text = table.concat(zone_block, "\n")
	return M.format_zone_block_pretty(raw_text)
end

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

	api.nvim_command("enew")
	local buf = api.nvim_get_current_buf()

	api.nvim_buf_set_option(buf, "buftype", "")
	api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	api.nvim_buf_set_option(buf, "swapfile", false)
	api.nvim_buf_set_name(buf, "rndc_zone:" .. zone)

	api.nvim_buf_set_var(buf, "rndczone_zone", zone)

	api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(zone_block, "\n"))
	api.nvim_buf_set_option(buf, "filetype", "conf")

	api.nvim_create_autocmd("BufWritePost", {
		buffer = buf,
		callback = function()
			M.commit_zone(buf)
		end,
	})
end

local function extract_zone_block_content(zone_name, text)
	local pattern = 'zone%s+"' .. zone_name:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") .. '"%s*{(.*)}%s*;'

	local content = text:match(pattern)
	if not content then
		local inside = {}
		local started = false
		for line in text:gmatch("[^\r\n]+") do
			if line:match('^zone%s+"' .. zone_name .. '"%s*{') then
				started = true
			elseif started and line:match("^};") then
				break
			elseif started then
				table.insert(inside, line)
			end
		end
		content = table.concat(inside, "\n")
	end
	if not content then
		return text
	end
	return content
end

local function shell_escape_single_quotes(str)
	return str:gsub("'", "'\\''")
end

function M.commit_zone(buf)
	buf = buf or api.nvim_get_current_buf()
	local ok, zone = pcall(api.nvim_buf_get_var, buf, "rndczone_zone")
	if not ok or not zone then
		api.nvim_err_writeln("Not a rndc zone buffer")
		return
	end

	local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
	local edited_text = table.concat(lines, "\n")

	local compact_text = M.format_zone_block_compact(edited_text)

	local inside_content = extract_zone_block_content(zone, compact_text)

	inside_content = inside_content:gsub("}%s*;", "};")

	local zone_block = "{ " .. inside_content .. " };"

	local escaped_text = shell_escape_single_quotes(zone_block)

	local zone_arg = "'" .. escaped_text .. "'"

	local cmd = string.format('rndc modzone "%s" %s 2>&1', zone, zone_arg)

	print("---- DEBUG: Running command: " .. cmd)
	print("---- DEBUG: Zone block passed as argument:")
	print(zone_block)
	print("---- End zone block ----")

	local handle = io.popen(cmd)
	if not handle then
		api.nvim_err_writeln("Failed to run rndc modzone command")
		return
	end

	local result = handle:read("*a")
	local success, _, code = handle:close()

	if success or code == 0 then
		print("rndc modzone committed successfully for zone: " .. zone)
	else
		api.nvim_err_writeln("rndc modzone failed: " .. result)
	end
end

-- List zones using dig and vim.ui.select with parameterization
function M.list_zones(opts)
	opts = opts or {}

	local bind_ip = opts.bind_ip or M.config.bind_ip
	local catalog_domain = opts.catalog_domain or M.config.catalog_domain

	local dig_cmd = string.format("dig -b %s @%s %s AXFR +noall +answer", bind_ip, bind_ip, catalog_domain)

	local handle = io.popen(dig_cmd)
	if not handle then
		vim.api.nvim_err_writeln("Failed to run dig command")
		return
	end

	local output = handle:read("*a")
	handle:close()

	local zones = {}

	for line in output:gmatch("[^\r\n]+") do
		local zone = line:match("%S+%s+%d+%s+IN%s+PTR%s+(%S+)")
		if zone then
			zone = zone:gsub("%.$", "")
			table.insert(zones, zone)
		end
	end

	if #zones == 0 then
		vim.api.nvim_out_write("No zones found in catalog\n")
		return
	end

	vim.ui.select(zones, {
		prompt = "Select DNS zone to edit:",
	}, function(choice)
		if choice then
			M.edit_zone(choice)
		end
	end)
end

return M
