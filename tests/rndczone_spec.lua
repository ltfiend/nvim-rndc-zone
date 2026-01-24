local rndczone = require("rndczone")

describe("rndczone", function()
	describe("trim", function()
		local trim = rndczone._internal.trim

		it("removes leading whitespace", function()
			assert.equals("hello", trim("   hello"))
		end)

		it("removes trailing whitespace", function()
			assert.equals("hello", trim("hello   "))
		end)

		it("removes both leading and trailing whitespace", function()
			assert.equals("hello", trim("   hello   "))
		end)

		it("handles tabs and mixed whitespace", function()
			assert.equals("hello world", trim("\t  hello world  \t"))
		end)

		it("returns empty string for whitespace-only input", function()
			assert.equals("", trim("   "))
		end)

		it("preserves internal whitespace", function()
			assert.equals("hello   world", trim("  hello   world  "))
		end)
	end)

	describe("shell_escape_single_quotes", function()
		local escape = rndczone._internal.shell_escape_single_quotes

		it("escapes single quotes", function()
			assert.equals("it'\\''s working", escape("it's working"))
		end)

		it("handles multiple single quotes", function()
			assert.equals("don'\\''t can'\\''t won'\\''t", escape("don't can't won't"))
		end)

		it("returns unchanged string without quotes", function()
			assert.equals("hello world", escape("hello world"))
		end)

		it("handles empty string", function()
			assert.equals("", escape(""))
		end)
	end)

	describe("format_zone_block_pretty", function()
		it("adds newlines after braces and semicolons", function()
			local input = 'zone "example.com" { type primary; file "/var/named/example.com.zone"; };'
			local result = rndczone.format_zone_block_pretty(input)
			assert.is_true(result:find("\n") ~= nil)
		end)

		it("indents nested content", function()
			local input = 'zone "example.com" { type primary; };'
			local result = rndczone.format_zone_block_pretty(input)
			assert.is_true(result:find("\ttype primary;") ~= nil)
		end)

		it("handles multiple levels of nesting", function()
			local input = 'zone "example.com" { also-notify { 10.0.0.1; }; };'
			local result = rndczone.format_zone_block_pretty(input)
			-- Should have double indentation for inner block content
			assert.is_true(result:find("\t\t10.0.0.1;") ~= nil)
		end)
	end)

	describe("format_zone_block_compact", function()
		it("removes extra whitespace", function()
			local input = 'zone "example.com" {\n\ttype primary;\n\tfile "/var/named/example.com.zone";\n};'
			local result = rndczone.format_zone_block_compact(input)
			-- Should not have tabs or excessive spaces
			assert.is_nil(result:find("\t"))
		end)

		it("collapses newlines", function()
			local input = "type primary;\nfile \"/var/named/example.com.zone\";"
			local result = rndczone.format_zone_block_compact(input)
			-- Check it's on one line (except after closing brace)
			local lines = {}
			for line in result:gmatch("[^\n]+") do
				table.insert(lines, line)
			end
			assert.equals(1, #lines)
		end)

		it("trims the result", function()
			local input = "  type primary;  "
			local result = rndczone.format_zone_block_compact(input)
			assert.equals("type primary;", result)
		end)
	end)

	describe("parse_showzone_output", function()
		it("extracts zone block from rndc output", function()
			local input = [[
zone "example.com" {
	type primary;
	file "/var/named/example.com.zone";
};
]]
			local result = rndczone.parse_showzone_output(input)
			assert.is_true(result:find('zone "example.com"') ~= nil)
			assert.is_true(result:find("type primary;") ~= nil)
		end)

		it("formats output with pretty printing", function()
			local input = 'zone "test.com" { type secondary; file "/zones/test.com"; };'
			local result = rndczone.parse_showzone_output(input)
			-- Should have newlines from pretty formatting
			assert.is_true(result:find("\n") ~= nil)
		end)
	end)

	describe("extract_zone_block_content", function()
		local extract = rndczone._internal.extract_zone_block_content

		it("extracts content from zone block", function()
			local input = 'zone "example.com" { type primary; file "/zones/example.com"; };'
			local result = extract("example.com", input)
			assert.is_true(result:find("type primary;") ~= nil)
		end)

		it("handles multiline zone blocks", function()
			local input = [[
zone "example.com" {
	type primary;
	file "/zones/example.com";
};]]
			local result = extract("example.com", input)
			assert.is_true(result:find("type primary;") ~= nil)
			assert.is_true(result:find("file") ~= nil)
		end)

		it("escapes special characters in zone name", function()
			-- Zone names with dots should be handled properly
			local input = 'zone "sub.example.com" { type secondary; };'
			local result = extract("sub.example.com", input)
			assert.is_true(result:find("type secondary;") ~= nil)
		end)
	end)

	describe("config", function()
		it("has debug option defaulting to false", function()
			assert.equals(false, rndczone.config.debug)
		end)

		it("can enable debug via setup", function()
			rndczone.setup({ debug = true })
			assert.equals(true, rndczone.config.debug)
			-- Reset to default
			rndczone.setup({ debug = false })
		end)
	end)
end)
