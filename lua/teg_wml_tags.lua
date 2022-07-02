if not wml_actions then wml_actions = {} end

------------------------------------------------------------------------------------------------------------------------

function wml_actions.place_door(udArgs)
	local via_terrain = false
	local function door(ground_type, type, wml)
		wml.type = type
		wesnoth.units.to_map(wml)
		if not via_terrain then wesnoth.set_terrain(wml.x, wml.y, ground_type, "overlay") end
	end

	local wml = wml.parsed(udArgs)
	wml.indestructible = nil; wml.direction = nil
	local se = udArgs.direction == "se" or string.match(udArgs.direction, "[%a]*^egG/") -- whether door location and facing is determined via map terrain
	wml.facing = "se"
	if not se then wml.facing = "sw" end
	if udArgs.indestructible then
		if se then
			door("^egG/", "Indestructible_Door", wml)
		else
			door("^egG\\", "Indestructible_Door", wml)
		end
	else
		if se then
			door("^egG/", "Door", wml)
		else
			door("^egG\\", "Door", wml)
		end
	end
end
------------------------------------------------------------------------------------------------------------------------

function wml_actions.lua_scenario(udArgs)
	wesnoth.dofile(string.format("~add-ons/The_Earths_Gut/lua_scenarios/%s", udArgs.scenario))
end

------------------------------------------------------------------------------------------------------------------------

function wml_actions.role_message(udArgs)
	--~ 	scout, thunderer, alchemist, guard, fighter
	local type = udArgs.type
	local else_speaker = udArgs.else_speaker
	local message = udArgs.message

	local cfg = helper.shallow_literal(udArgs)
	if type == "scout" then cfg.type = "Dwarvish Scout,Dwarvish Pathfinder,Dwarvish Explorer"
	elseif type == "thunderer" then cfg.type = "Dwarvish Thunderer,Dwarvish Thunderguard,Dwarvish Dragonguard"
	elseif type == "alchemist" then cfg.type = "Alchemist,Potion Smith,Master of Alchemy"
	elseif type == "guard" then cfg.type = "Dwarvish Guardsman,Dwarvish Stalwart,Dwarvish Sentinel"
	elseif type == "fighter" then cfg.type = "Dwarvish Fighter,Dwarvish Steelclad,Dwarvish Lord"
	end
	table.insert(cfg, {"not", { id = else_speaker }})
	local role_speaker = wesnoth.units.find_on_map(cfg)[1]
	if role_speaker then
		wml_actions.message({id = role_speaker.id, message = message})
	else
		wml_actions.message({id = else_speaker, message = message})
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

--~ locations or units, top-down-left-right on the map
function wml_actions.sort_array(udArgs)
	local variable = udArgs.variable
	local tArray = wml.array_access.get(variable)

	local function top_down_left_right(uFirstElem, uSecElem)
		if uFirstElem.x == uSecElem.x then return uFirstElem.y < uSecElem.y end
		return uFirstElem.x < uSecElem.x
	end
	table.sort(tArray, top_down_left_right)
	wml.array_access.set(variable, tArray)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

function wml_actions.nearest_hex(cfg, only_return, calc_via_reach)
	local error_msg = "error in [nearest_hex] while reading the source location"
	local nX = tonumber(cfg.x_source) or helper.wml_error(error_msg)
	local nY = tonumber(cfg.y_source) or helper.wml_error(error_msg)
	local sVariable = cfg.variable or "nearest_hex"

	local tPossibleNearestHexes = wesnoth.get_locations(cfg)
	local tNearestHex
	local nNearestHexDistance = MAX_NUMBER
	local nPossibleNearestHexDistance = MAX_NUMBER
	for nCurrentHex, tCurrentHex in ipairs(tPossibleNearestHexes) do
		if calc_via_reach then
			path, nPossibleNearestHexDistance = wesnoth.find_path(nX, nY, tCurrentHex[1], tCurrentHex[2],
				{ ignore_teleport = true, viewing_side = 0, ignore_units = false })
		else
			nPossibleNearestHexDistance = helper.distance_between(nX, nY, tCurrentHex[1], tCurrentHex[2])
		end
		if(nPossibleNearestHexDistance < nNearestHexDistance) then
			nNearestHexDistance = nPossibleNearestHexDistance
			tNearestHex = tCurrentHex
		end
	end
	if not tNearestHex then
		helper.warning("no suitable hex found in [nearest_hex]")
		return
	end
	if not only_return then
		wesnoth.set_variable(sVariable, { x = tNearestHex[1], y = tNearestHex[2], terrain = wesnoth.get_terrain(tNearestHex[1], tNearestHex[2]) })
	end
	return tNearestHex
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

function wml_actions.place_room_units(cfg)
	local number = helper.rand(cfg.number)

	local cfg = helper.shallow_literal(cfg)

	local width, heigth = wesnoth.get_map_size()
	table.insert(cfg, { "and", { radius = math.ceil(math.sqrt(2) * math.max(width, heigth)), x = cfg.x_source, y = cfg.y_source, { "filter_radius", { terrain = cfg.terrain }} }})

	local locs = wesnoth.get_locations(cfg)

	local size = #locs
	for current = 1, number do
		if size == 0 then
			helper.warning("could not place all units required in [place_room_units]; source location: ".. tostring(cfg.x_source) .. ", " .. tostring(cfg.y_source))
			return
		end
		local pos = helper.rand(string.format("1..%u", size))
		wesnoth.units.to_map({ side = cfg.side, type = helper.rand(cfg.types), x = locs[pos][1], y = locs[pos][2], upkeep = "loyal", ai_special = "guardian", generate_name = false })
		size = size - 1; table.remove(locs, pos)
	end
end


----------------------------------------------------------------------------------------------------------------------------------------------------------------

function wml_actions.check_version(cfg)
	local required = cfg.required or helper.wml_error("[check_version] missing required required= attribute")
	local variable = cfg.variable or "bfw_version_is_sufficient"

	local sufficient = wesnoth.compare_versions and wesnoth.compare_versions(wesnoth.game_config.version, ">=", required)
	wesnoth.set_variable(variable, sufficient)
	if not sufficient then
		wml_actions.message({ speaker = "narrator", image = "wesnoth-icon.png", message = cfg.message })
		wml_actions.kill({ animate = true })
		wml_actions.endlevel({ result = "defeat" })
	end
end

function wml_actions.sc_transform_type(cfg)
	local function handle_array(array, recalls)
		for i, unit in ipairs(array) do
			if unit.type == cfg.old then
				local orig_exp = unit.experience
				unit.experience = unit.max_experience
				local original_advances_to = unit.advances_to
				unit.advances_to = { cfg.new }
				wml_actions.store_unit({ variable = "LUA_sc_transform_type", {"filter", { id = unit.id }} })
				wesnoth.extract_unit(unit)
				if recalls then wml_actions.unstore_unit({ variable = "LUA_sc_transform_type", find_vacant = true, advance = true, x = 1, y = 1, check_passability = false })
				else wml_actions.unstore_unit({ variable = "LUA_sc_transform_type", find_vacant = false, advance = true })
				end
				wesnoth.set_variable("LUA_sc_transform_type")
				unit = wesnoth.units.find_on_map({ id = unit.id })[1]
				unit.experience = orig_exp
				unit.advances_to = original_advances_to
				if recalls then wesnoth.units.to_recall(unit) end
			end
		end
	end
	handle_array(wesnoth.units.find_on_map({}))
	handle_array(wesnoth.units.find_on_recall({}), true)

	for variable in string.gmatch(cfg.variable, "[^%s,][^,]*") do
		local max_i = wesnoth.get_variable(variable .. ".length") - 1
		for i = 0, max_i do
			local var_string = string.format("%s[%u]", variable, i)
			local unit = wml.variables[var_string]
			if unit.type == cfg.old then
				unit.type = cfg.new
				wesnoth.set_variable(var_string, unit)
			end
		end
	end
end

function wml_actions.teg_recall_variable(cfg)
	local id = cfg.id
	local types = cfg.type
	local variable = cfg.variable
	local x,y = cfg.x, cfg.y
	assert(not types or not id)
	assert(type(x) == "number" and type(y) == "number")

	local max_i = wesnoth.get_variable(variable .. ".length") - 1
	local unit
	local var_string
	local function recall()
		wesnoth.units.to_recall(unit)
		wesnoth.set_variable(var_string)
		wml_actions.recall({ id = unit.id, x = x, y = y })
		assert(wesnoth.get_variable(variable .. ".length") == max_i)
	end
	if id then
		for i = 0, max_i do
			var_string = string.format("%s[%u]", variable, i)
			unit = wml.variables[var_string]
			if unit.id == id then return recall() end
		end
	else
		for type in string.gmatch(types, "[^%s,][^,]*") do
			for i = 0, max_i do
				var_string = string.format("%s[%u]", variable, i)
				unit = wml.variables[var_string]
				if unit.type == type then return recall() end
			end
		end
	end
	local msg = "could not recall unit: "
	if id then helper.warning(msg .. " id: " .. id)
	else helper.warning(msg .. "type: " .. types)
	end
end

function wml_actions.teg_xp_to_killer(cfg)
	local event_context = wesnoth.current.event_context
	local primary_unit = wesnoth.get_unit(event_context.x1, event_context.y1).__cfg
	local second_unit = wesnoth.get_unit(event_context.x2, event_context.y2 ).__cfg
	if primary_unit.level == 0 then
		second_unit.experience = second_unit.experience + math.floor(wesnoth.game_config.kill_experience / 2)
	else
		second_unit.experience = second_unit.experience + wesnoth.game_config.kill_experience * primary_unit.level
	end
	wesnoth.set_variable("second_unit", second_unit)
	wml_actions.unstore_unit({ variable = "second_unit", advance = true, find_vacant = false })
end
