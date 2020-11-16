--base file for lua functionalities

--variable prefixes in lua:
--n: number
--s: string
--b: boolean
--t: table
--wt: wml table
--ud: userdata
--u: unknown

------------------------------------------------------------------------------------------------------------------------
--global functions and constants
MAX_NUMBER = math.huge
------------------------------------------------------------------------------------------------------------------------
--avoiding execution errors without wesnoth
if not wesnoth then
	package.path = package.path .. ";../../../../../data/lua/?.lua"
	wesnoth = require("wesnoth")
end
wml_actions = wesnoth.wml_actions
_ = wesnoth.textdomain("wesnoth-The_Earths_Gut")
-- #textdomain wesnoth-The_Earths_Gut
------------------------------------------------------------------------------------------------------------------------
--disabling compatibility-1.8.lua
--I want this to check during 1.10 (stable).
--TODO: remove when that file gets removed
--~ wesnoth["get_side"] = nil
wesnoth["get_side_count"] = nil
wesnoth["get_unit_type_ids"] = nil
wesnoth["get_unit_type"] = nil
wesnoth["register_wml_action"] = nil
--~ wesnoth["fire"] = nil
------------------------------------------------------------------------------------------------------------------------
--loading of libraries
helper = wesnoth.require("lua/helper.lua")

pcall(wesnoth.dofile, "lua/mydebug.lua")
local loaded, debug_utils = pcall(wesnoth.dofile, "~add-ons/Wesnoth_Lua_Pack/debug_utils.lua")
dbms = debug_utils.dbms
sdbms = debug_utils.sdbms

local sLuaPath = "~add-ons/The_Earths_Gut/lua/%s.lua"
local function teg_dofile(sFile) return wesnoth.dofile(string.format(sLuaPath, sFile)) end
local function teg_require(sFile) return wesnoth.require(string.format(sLuaPath, sFile)) end

units = teg_dofile("units")
teg_dofile("teg_wml_tags")
teg_dofile("ai_controller")
------------------------------------------------------------------------------------------------------------------------
--basic helper functionalities

--tested!
function helper.equals(t1, t2)
	local type1 = type(t1)
	assert(type1 ~= "function"); assert(type1 ~= "thread")

	local function dump_userdata(data, mt)
		if mt == "unit" then return data.__cfg end
		if mt== "wml object" then return data.__literal end
		return tostring(data)
	end

	if type1 == "userdata" then
		local mt1, mt2 = getmetatable(t1), getmetatable(t2)
		if mt1 ~= mt2 then return false end
		t1, t2 = dump_userdata(t1, mt1), dump_userdata(t2, mt2)
	end
	if t1 == t2 then return true end
	if type(t1) ~= "table" then return false end
	if #t1 ~= #t2 then return false end

	local match = true
	for current_key, current_value in pairs(t1) do
		match = helper.equals(current_value, t2[current_key])
		if not match then return false end
	end

	return true
end

function helper.warning(sMessage)
	wml_actions.wml_message({ message = sMessage, logger = "warn" })
end

function helper.deep_copy(source)
	local copied = {}

	local function doit(src)
		local dst = {}
		copied[src] = dst
		for k,v in pairs(src) do
			if type(v) ~= "table" then
				dst[k] = v
			else
				dst[k] = copied[v] or doit(v)
			end
		end
		return setmetatable(dst, getmetatable(src))
	end

	if type(source) ~= "table" then
		return source
	else
		return doit(source)
	end
end


------------------------------------------------------------------------------------------------------------------------

local main = {}

	function main.main(udArgs)
		units.main()


	end

------------------------------------------------------------------------------------------------------------------------

return main
