local M = {}

local api = vim.api

-- Helper: trim whitespace
local function trim(s)
	return s:match("^%s*(.-)%s*$")
end

-- Pretty format zone block text for editing:
-- Add newlines after { and ;, indent nested blocks by tabs.
function M.format_zone_block_pretty(text)
	-- Replace all { with {\n and ; with ;\n for better line breaks
	local step1 = text:gsub("{", "{\n"):gsub(";", ";\n")

	local lines = {}
	local indent_level = 0

	for line in step1:gmatch("[^\r\n]+") do
		line = trim(line)
		-- Reduce indent if line contains closing }
		if line:find("^}") then
			indent_level = indent_level - 1
			if indent_level < 0 then
				indent_level = 0
			end
		end

		table.insert(lines, string.rep("\t", indent_level) .. line)

		-- Increase indent if line contains opening {
		if line:find("{") and not line:find("}") then
			indent_level = indent_level + 1
		end
	end

	return table.concat(lines, "\n")
end

-- Compact formatting for rndc modzone (reverse pretty formatting):
-- Remove all newlines except after }
-- Remove indentation and extra spaces
function M.format_zone_block_compact(text)
	-- Remove tabs/spaces at line starts
	local no_indent = text:gsub("[\t ]+", " ")

	-- Remove newlines except after }
	local compact = no_indent:gsub("\n%s*", " ")
	-- Insert newline after each }
	compact = compact:gsub("}%s*", "}\n")

	-- Trim leading/trailing spaces
	compact = trim(compact)
	return compact
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

-- Parse rndc showzone output and pretty format it for editing
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

	-- Set autocmd on BufWritePost to commit changes
	api.nvim_create_autocmd("BufWritePost", {
		buffer = buf,
		callback = function()
			M.commit_zone(buf)
		end,
	})
end

-- Commit zone changes with rndc modzone after compacting format
local function shell_escape_single_quotes(str)
	-- escape ' as '\'' for POSIX shell inside single quotes
	-- example: abc'def -> 'abc'\''def'
	return str:gsub("'", "'\\''")
end

-- Extract inside content from full zone block text
local function extract_zone_block_content(zone_name, text)
	-- pattern to match: zone "zone_name" { ... };
	-- capture content inside braces

	local pattern = 'zone%s+"'
		.. zone_name:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") -- escape magic chars
		.. '"%s*{(.*)}%s*;'

	local content = text:match(pattern)
	if not content then
		-- fallback: try to extract lines between zone header and last brace
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
		-- if all else fails, return whole text (will likely fail)
		return text
	end
	return content
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

	-- Compact and fix zone block for passing as argument:
	local compact_text = M.format_zone_block_compact(edited_text)

	-- Extract inside content only (strip outer zone "name" { ... }; wrapper)
	local inside_content = extract_zone_block_content(zone, compact_text)

	-- Clean up: remove newlines between } and ; inside the content
	inside_content = inside_content:gsub("}%s*;", "};")

	-- Wrap inside content with braces and trailing semicolon
	local zone_block = "{ " .. inside_content .. " };"

	-- Escape single quotes for shell
	local function shell_escape_single_quotes(str)
		return str:gsub("'", "'\\''")
	end

	local escaped_text = shell_escape_single_quotes(zone_block)

	-- Wrap entire zone block in single quotes for shell command
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

return M
