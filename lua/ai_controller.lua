-- scenarios that use this file: S06 ("The Great Gates"), S15 ("Save The Heir"), S17 ("Return"), S21 ("Wesnoth Soldiers")
if not wml_actions then wml_actions = {} end
local debug_utils = pcall(wesnoth.dofile, "~add-ons/Wesnoth_Lua_Pack/debug_utils.lua")

-- We need one of these in every file that uses one of these, apparently:
local _ = wesnoth.textdomain("wesnoth-The_Earths_Gut")

------------------------------------------------------------------------------------------------------------------------

local function calc_position_danger(side, x, y)
	local location_set = wesnoth.require "lua/location_set.lua"
	local adjacent = location_set.create()
	for u, v in helper.adjacent_tiles(x, y) do
		adjacent:insert(u, v)
	end

	local reach_units = {}
	for i, u in ipairs(wesnoth.units.find_on_map({ { "filter_side", { { "enemy_of", { side = side }} }} })) do
		local ucfg = u.__cfg
		local reachable = location_set.of_pairs(wesnoth.paths.find_reach(u, { ignore_units = false, ignore_teleport = false, additional_turns = 0, ignore_visibility = true }))
		if (wesnoth.game_config.debug) then
			if u.x == 6 then
				reachable_pairs = reachable:to_pairs()
				for j, loc in ipairs(reachable_pairs) do
					wml_actions.label({ text = "*", x = loc[1], y = loc[2] })
				end
			end
		end
		reachable:inter(adjacent)
		if reachable:size() > 0 then
			local reach_unit = { unit = u, level = ucfg.level}
			local function mark_as_reachable(x, y)
				if false then
					local data = adjacent:get(x, y)
					data[u] = ucfg.level
					adjacent:insert(x, y, data)
				end
				table.insert(reach_unit, { x, y })
			end
			reachable:iter(mark_as_reachable)
			table.insert(reach_units, reach_unit)
		else
			if (wesnoth.game_config.debug) then
				wesnoth.log("debug", "calc_position_danger " .. tostring(i) .. " nothing reachable found!" .. tostring(reachable:size()), false)
			end
		end
	end
	if (wesnoth.game_config.debug) then
		if #reach_units > 0 then
			wml_actions.message({ speaker = "narrator", message = tostring(reach_units[1].unit)})
			if false then dbms(reach_units) end
		end -- Hopefully we can avoid attempts to index a nil value in here...
	end -- Wish I had a better debug check...
	local function compare(u1, u2)
		if u1.level == u2.level then
			return #u1> #u2
		end
		return u1.level < u2.level
	end
	table.sort(reach_units, compare)
	if (wesnoth.game_config.debug) then
		if #reach_units > 0 then
			if false then dbms(reach_units) end
		end
		for i, loc in ipairs(wesnoth.map.find({})) do wml_actions.label({ x = loc[1], y = loc[2], text = "" }) end
		if #reach_units > 0 then
			for i, loc in ipairs(reach_units[1]) do wml_actions.label({ x = loc[1], y = loc[2], text = "*" }) end
		end
	end

	local function calc_danger(adjacent)
		local danger = 0
		local function do_it(x1, y1, data)
			if type(data) ~= "table" then danger = danger + 0.0
			elseif data.level < 1 then danger = danger + 0.5
			elseif data.level < 2 then danger = danger + 1.0
			elseif data.level < 3 then danger = danger + 1.5
			else danger = danger + 2
			end
		end
		adjacent:iter(do_it)
		return danger
	end

	-- toplevel first available here, but not before this:
	local function distribute_units(reach_units, adjacent, toplevel)
		local function remove_used_up_hexes_and_units_accordingly_to_hexes(reach_units, hex)
			local i = #reach_units
			while true do
				if i < 1 then break end
				local u = reach_units[i]
				for j, v in ipairs(u) do
					if v[1] == hex[1] and v[2] == hex[2] then
						table.remove(u, j)
					end
				end
				if #u == 0 then
					if (wesnoth.game_config.debug) then
						if #reach_units > 0 then
							dbms(reach_units[i], "removing")
						end
					end
					table.remove(reach_units, i)
				end
				i = i - 1
			end
		end
		while true do
			if (wesnoth.game_config.debug) then
				if toplevel then dbms(adjacent) end
			end
			if #reach_units < 1 then return adjacent end
			local u = reach_units[#reach_units]
			if (wesnoth.game_config.debug) then
				if toplevel then dbms("processing: " .. u.unit.name) end
			end
			assert(#u >= 1)
			local hex
			if #u == 1 then
				hex = u[1]
			else
				if (wesnoth.game_config.debug) then
					if (#u > 0) then
						if toplevel then dbms(u) end
					end
					wesnoth.log("debug", "entering multi-hex case", false)
				end
				local best_danger = 0
				local best_hex
				for i, loc in ipairs(u) do
					local adjacent_saved = adjacent
					local adjacent = helper.deep_copy(adjacent)
					if (wesnoth.game_config.debug) then
						assert(helper.equals(adjacent, adjacent_saved))
					end
					local reach_units_saved = reach_units
					local reach_units = helper.deep_copy(reach_units)
					if (wesnoth.game_config.debug) then
						assert(helper.equals(reach_units_saved, reach_units))
					end
					local reach_unit = reach_units[#reach_units]
					reach_unit = { unit = reach_unit.unit, level = reach_unit.level, loc }
					if (wesnoth.game_config.debug) then
						if toplevel then dbms(reach_unit) end
					end
					reach_units[#reach_units] = reach_unit
					assert(#reach_units[#reach_units] == 1)
					if (wesnoth.game_config.debug) then
						if (i > 0) then
							if (#u > 0) then
								wesnoth.log("debug", "checking case " .. tostring(i) .. " for you.", false)
								dbms("checking case " .. tostring(i) .. " for " .. dbms(u, true, false, true, false, true))
							end
						end
						if (#reach_units > 0) then
							wesnoth.log("debug", "which units are reachable?", false)
							dbms(dbms(reach_units, true, "reach_units", true, false, true))
						end
					end
					adjacent = distribute_units(reach_units, adjacent)
					local danger = calc_danger(adjacent)
					if (wesnoth.game_config.debug) then
						if toplevel then dbms(adjacent, true, "resulting adjacent") end
						if (danger > 0) then
							dbms(danger, true, "resulting danger")
						end
					end
					if danger > best_danger then
						best_danger = danger
						best_hex = loc
					end
				end
				hex = best_hex
				if (wesnoth.game_config.debug) then
					if toplevel then dbms(adjacent, true, "chosen adjacent") end
					if (#reach_units > 0) then
						dbms(reach_units)
					end
				end
			end
			if (wesnoth.game_config.debug) then
				if toplevel then dbms(adjacent) end
			end
			local previous = adjacent:get(hex[1], hex[2])
			if (wesnoth.game_config.debug) then
				if toplevel then dbms(previous) end
			end
			if type(previous) == "table" then
				assert(previous.level >= u.level)
				table.remove(reach_units)
				if (wesnoth.game_config.debug) then
					if toplevel then dbms("discarding: " .. previous.unit.name) end
				end
			else
				if (wesnoth.game_config.debug) then
					if (#u > 0) then
						dbms("inserting:" .. u.unit.name)
					end
				end
				adjacent:insert(hex[1], hex[2], u)
				table.remove(reach_units)
				if (wesnoth.game_config.debug) then
					if (#reach_units > 1) then dbms(reach_units) end
				end
				remove_used_up_hexes_and_units_accordingly_to_hexes(reach_units, hex)
			end
		end
		return adjacent
	end
	-- end distribute_units(); toplevel is now no longer available
	adjacent = distribute_units(reach_units, adjacent, true)
	if (wesnoth.game_config.debug) then
		for i, loc in ipairs(wesnoth.map.find({})) do wml_actions.label({ x = loc[1], y = loc[2], text = "" }) end
		local function put_unit_names(x, y, data)
			if type(data) ~= "table" then return end
			wml_actions.label({ x = x, y = y, text = data.unit.name })
		end
		if (#adjacent > 0) then dbms(adjacent) end
		adjacent:iter(put_unit_names)
	end
	local danger = calc_danger(adjacent)
	if (wesnoth.game_config.debug) then
		if (danger > 0) then
			if false then dbms(danger) end
		end
	end
	return danger
end

function wml_actions.ai_controller_new_force_to_heal_wounded_units(cfg)
	local side = wesnoth.current.side

	local function move_wounded_unit_to(u, loc)
		local path = wesnoth.paths.find_path(u, loc[1], loc[2], { ignore_teleport = true, ignore_visibility = true })
		if (wesnoth.game_config.debug) then
			if (#path > 0) then
				wml_actions.message({ speaker = "narrator", message = string.format("found path: %s", dbms(path, false, "path", true, false, true)) })
			end
		end
		if #path == 0 then
			helper.warning("no path found to force " .. u.name .. " to heal")
			return
		end
		assert(#path >= 2)
		local dest_length = wml.variables["LUA_destinations.length"]
		wesnoth.set_variable(string.format("LUA_destinations[%u].x", dest_length), loc[1])
		wesnoth.set_variable(string.format("LUA_destinations[%u].y", dest_length), loc[2])
		for i, loc in ipairs(path) do
			if i == 1 then
				-- ???
			else
				if (wesnoth.game_config.debug) then
					wml_actions.message({ speaker = "narrator", message = string.format("checking loc: (%u, %u)", loc[1], loc[2]) })
				end
				local cost = wesnoth.unit_movement_cost(u, wesnoth.get_terrain(loc[1], loc[2]))
				local new_moves = u.moves - cost
				if (wesnoth.game_config.debug) then
					wml_actions.message({ speaker = "narrator", message = string.format("new moves: %i", new_moves) })
				end
				if new_moves >= 0 then
					if (wesnoth.game_config.debug) then
						wml_actions.message({ speaker = "narrator", message = string.format("move step: (%u, %u)", loc[1], loc[2]) })
					end
					u.moves = new_moves
					wml_actions.move_unit({ id = u.id, to_x = loc[1], to_y = loc[2],
						check_passability = false, fire_event = false })
				else
					u.moves = 0
					if (wesnoth.game_config.debug) then
						wml_actions.message({ speaker = "narrator", message = string.format("%s stopped on the way to heal before (%u, %u))", u.name, loc[1], loc[2]) })
					end
					break
				end
				if i == #path then
					u.moves = 0
					u.role = "force_heal_heals_side" .. tostring(side)
					wml_actions.capture_village({ side = u.side, x = u.x, y = u.y })
					if (wesnoth.game_config.debug) then
						wml_actions.message({ speaker = "narrator", message = string.format("%s heals now at (%u, %u)", u.name, loc[1], loc[2]) })
					end
				end
			end
		end
	end

	local function handle_healing_units()
		local units = wesnoth.units.find_on_map({ role = "force_heal_heals_side" .. tostring(side) })
		for i, u in ipairs(units) do
			if u.hitpoints == u.max_hitpoints then
				u.role = ""
				if (wesnoth.game_config.debug) then
					wml_actions.message({ speaker = "narrator", message = string.format("%s has finished healing at (%u, %u))", u.name, u.x, u.y) })
				end
			else
				u.moves = 0
				u.attacks_left = 0
				if (wesnoth.game_config.debug) then
					wml_actions.message({ speaker = "narrator", message = string.format("%s continues to heal at (%u, %u))", u.name, u.x, u.y) })
				end
			end
		end
	end
	local function free_unneccessarily_occupied_villages()
		-- TODO: include side 1, too?
		local units = wesnoth.units.find_on_map({ side = side, { "filter_location", { terrain = "*^V*" }}, formula = "max_hitpoints = hitpoints" })
		for i, u in ipairs(units) do
			for x, y in helper.adjacent_tiles(u.x, u.y, false) do
				if not wesnoth.units.get(x, y) then
					wml_actions.move_unit({ id = u.id, to_x = x, to_y = y })
					break
				end
			end
		end
	end
	free_unneccessarily_occupied_villages()
	handle_healing_units()

	local filter = wml.shallow_literal(wml.get_child(cfg, "filter"))
	local forbidden_sides = cfg.forbidden_sides
	filter.formula = "max_hitpoints > hitpoints"
	table.insert(filter, { "not", { role = "force_heal_heals_side" .. tostring(side) }})
	local wounded_units = wesnoth.units.find_on_map(filter)

	for i, u in ipairs(wounded_units) do
		assert(u.side == side)
		if (wesnoth.game_config.debug) then
			wml_actions.message({ speaker = "narrator", message = string.format("found unit to heal: %s", u.name) })
		end
		local filter =
		{
			x_source = u.x,
			y_source = u.y,
			{ "not",
				{
					{ "filter", {} }
				}
			},
			{ "not",
				{ find_in = "LUA_destinations" }
			},
			x = cfg.x,
			y = cfg.y,
			{ "and",
				{
					{ "filter_owner", { { "not", {}} }},
					{ "or",
						{
							{ "filter_owner",
								{
									{ "not", { side = forbidden_sides }}
								}
							}
						}
					}
				}
			}
		}
		if (wesnoth.game_config.debug) then
			if false then dbms(filter) end
		end
		if not wesnoth.get_terrain_info(wesnoth.get_terrain(u.x, u.y)).village then
			local function calc_heal_loc()
				local heal_loc = wml_actions.nearest_hex(filter, true, true)
				if not heal_loc then return end
				local danger = calc_position_danger(u.side, heal_loc[1], heal_loc[2])
				if danger <= 1 then return heal_loc end
				local dest_length = wml.variables["LUA_destinations.length"]
				wesnoth.set_variable(string.format("LUA_destinations[%u].x", dest_length), heal_loc[1])
				wesnoth.set_variable(string.format("LUA_destinations[%u].y", dest_length), heal_loc[2])
				return calc_heal_loc()
			end
			if (wesnoth.game_config.debug) then
				wesnoth.log("debug", "finding heal location...", false)
			end
			local heal_loc = calc_heal_loc()
			u.attacks_left = 0 --in any case, especially if trapped
			if heal_loc then
				if (wesnoth.game_config.debug) then
					wml_actions.message({ speaker = "narrator", message = string.format("found heal location: (%u,%u)", heal_loc[1], heal_loc[2]) })
				end
				move_wounded_unit_to(u, heal_loc)
			else
				helper.warning("no location found to force " .. u.name .. " to heal")
			end
		end
	end
	wesnoth.set_variable("LUA_destinations")
end

function wml_actions.ai_controller_place_reserved_labels(cfg)
	local locs = wesnoth.map.find({ x = cfg.x, y = cfg.y })
	local color = wesnoth.sides[cfg.side].color
	local color_number = tonumber(color)
	if color_number then color = color_number end
	local rgb = wml.get_child(wml.variables["team_colors"], "color_range", color).rgb
	color = string.sub(rgb, 1, 6)
	local text = string.format(tostring(_"<span color='#%s'>reserved</span>"), color)
	for i, loc in ipairs(locs) do
		wml_actions.label({ x = loc[1], y = loc[2], text = text })
	end
end
----------------------------------------------------------------------------------------------------------
