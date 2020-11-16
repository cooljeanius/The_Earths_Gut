local filename
filename = "16_Ferry_crossing.cfg"
local new = io.open("new" .. filename, "w")

local output = ""
local finish = true
local bracketed = false
local TEG_MESSAGE_start, TEG_MESSAGE_end
local function handle_line(line)
	if finish then
		TEG_MESSAGE_start, TEG_MESSAGE_end = string.find(line, "{TEG_MESSAGE")
		if not TEG_MESSAGE_start then
			new:write(line .. "\n")
			return
		end
		local space = string.find(line, " ", TEG_MESSAGE_end + 3)
		local speaker = string.sub(line, TEG_MESSAGE_end + 2, space - 1)

		local id = "id"
		if speaker == "unit" or speaker == "second_unit" or speaker == "narrator" then id = "speaker" end

		finish = string.find(line, "}", space + 2)
		local last_char = string.len(line)
		if finish then last_char = finish -1 end
		local message = string.sub(line, space + 1, last_char)
		if string.sub(message, 1, 1) == "(" then
			message = string.sub(message, 2)
			bracketed = true
		end
		if finish and bracketed then message = string.sub(message, 1, string.len(message) - 1) end
		output = output .. string.rep("\t", TEG_MESSAGE_start -1) .. "[message]\n"
			.. string.rep("\t", TEG_MESSAGE_start) .. id .. "=" .. speaker .. "\n"
			.. string.rep("\t", TEG_MESSAGE_start) .. "message=" .. message .. "\n"
		if finish then output = output .. string.rep("\t", TEG_MESSAGE_start -1) .. "[/message]\n" end
	else
		finish = string.find(line, "}")
		if finish then line = string.sub(line, 1, string.len(line) - 1)
			if bracketed then line = string.sub(line, 1, string.len(line) - 1) end
		end
		if finish then
			output = output .. line .. "\n" .. string.rep("\t", TEG_MESSAGE_start -1) .. "[/message]\n"
		else
			output = output .. line .. "\n"
		end
	end

	if finish then
		new:write(output)
		output = ""; bracketed = false
	end
end

for line in io.lines(filename) do
handle_line(line)
end

io.close(new)
