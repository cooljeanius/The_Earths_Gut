if not wml_actions then wml_actions = {} end

function wml_actions.prison_put_prisoners(udArgs)
	local variable = udArgs.variable
	local dwarves = helper.get_variable_array(variable)
	local locations = wesnoth.get_locations({terrain = udArgs.terrain})

	local number_put = 0
	local level_threes_left = true
	local level_twos_left = true
	local level_ones_left = true
	local function which_levels_are_left(level)
		if level == 3 then level_threes_left = false
		elseif level == 2 then level_twos_left = false
		else level_ones_left = false end
	end
	local function put_level_prisoner(level, current_loc)
		for current_index, current_unit in ipairs(dwarves) do
			if current_unit.race == "troll" then
			elseif current_unit.level == level then
				wesnoth.put_unit(current_loc[1], current_loc[2], current_unit)
				wesnoth.set_terrain(current_loc[1], current_loc[2], "Rr")
				number_put = number_put + 1
				table.remove(dwarves, current_index)
				return true
			elseif current_unit.level <= level then
				which_levels_are_left(level)
				return false
			end
		end
		which_levels_are_left(level)
		return false
	end

	--~ 	the unit array had been sorted according to level
	for current_index, current_loc in ipairs(locations) do
		if level_threes_left and number_put <= 2 and put_level_prisoner(3, current_loc) then
		elseif level_twos_left and number_put <= 6 and put_level_prisoner(2, current_loc) then
		elseif level_ones_left and put_level_prisoner(1, current_loc) then
		else wesnoth.put_unit(current_loc[1], current_loc[2], {type = helper.rand("Dwarvish Fighter,Dwarvish Thunderer,Dwarvish Scout")})
		end
	end

	helper.set_variable_array(variable, dwarves)
end

------------------------------------------------------------------------------------------------------------------------

function wml_actions.prison_execute_prisoner(udArgs)
	if not udArgs.execute then return end

	local tPrisonersLocations = helper.get_variable_array("locPrisoners")
	local nPrisonersLocationsLength = #tPrisonersLocations
	local tCellDoorsLocations = helper.get_variable_array("locCellDoors")

	local sGateId = "southern_magic_gate"
	if nPrisonersLocationsLength <= 7 then sGateId = "northern_magic_gate" end

	local udExecutioner = wesnoth.get_units({ id = "executioner" })[1]
	local udPrisoner = wesnoth.get_units({ x = tPrisonersLocations[nPrisonersLocationsLength].x , y = tPrisonersLocations[nPrisonersLocationsLength].y})[1]

	wml_actions.kill({ x = tCellDoorsLocations[nPrisonersLocationsLength].x, y = tCellDoorsLocations[nPrisonersLocationsLength].y, fire_event = true})
	local udGate = wesnoth.copy_unit(wesnoth.get_units({id = sGateId})[1]); wml_actions.kill({ id = sGateId, fire_event = true})

	wml_actions.move_unit({ id = "executioner", to_x = udPrisoner.x, to_y = udPrisoner.y})
	wesnoth.fire_event("lead_away_dialog", udExecutioner.x, udExecutioner.y, udPrisoner.x, udPrisoner.y)
	wesnoth.extract_unit(udExecutioner)
	wesnoth.extract_unit(udPrisoner)
	wml_actions.move_units_fake({ 	{"fake_unit", { type = udExecutioner.type, x = tostring(udExecutioner.x) .. ",26", y = tostring(udExecutioner.y) .. ",8", side = udExecutioner.side}},
									{"fake_unit", { type = udPrisoner.type, x = tostring(udPrisoner.x) .. ",25", y = tostring(udPrisoner.y) .. ",9", side = udPrisoner.side}}
								})
	udExecutioner.x = 26; udExecutioner.y = 8; wesnoth.put_unit(udExecutioner)
	udPrisoner.x = 25; udPrisoner.y = 9; udPrisoner.facing = "se"; wesnoth.put_unit(udPrisoner)

	wesnoth.put_unit(udGate); wml_actions.terrain({ x = udGate.x, y = udGate.y, layer = "overlay", terrain = "^egG/"}); wml_actions.redraw({})
	wesnoth.fire_event("execution_dialog", udExecutioner.x, udExecutioner.y, udPrisoner.x, udPrisoner.y)

	local nDamage = 14
	local wtAnimate = { flag = "defend", { "filter", { id = udPrisoner.id }}, { "facing", { { "filter", { id = "executioner" }} }}, { "primary_attack", { range = "melee" }}, { "secondary_attack", { range = "melee" }}, hits = false, with_bars = true, text = nDamage, red = 255 }
	local wtAnimateUnit = { flag = "attack", { "filter", { id = "executioner" }}, { "facing", { { "filter", { id = udPrisoner.id }} }}, { "primary_attack", { name = helper.get_child(udExecutioner.__cfg, "attack").name }}, hits = true, { "animate", wtAnimate}, with_bars = true }

	while true do
		wml_actions.animate_unit(wtAnimateUnit)
		udPrisoner.hitpoints = udPrisoner.hitpoints - nDamage
		if udPrisoner.hitpoints < 1 then break end
		wml_actions.sound({ name = "dwarf-hit-1.ogg,dwarf-hit-2.ogg,dwarf-hit-3.ogg,dwarf-hit-4.ogg"})
	end
	wml_actions.kill({id = udPrisoner.id, animate = true, fire_event = true})

	wesnoth.set_variable(string.format("locPrisoners[%u]", nPrisonersLocationsLength - 1))
	wesnoth.set_variable(string.format("locCellDoors[%u]", nPrisonersLocationsLength - 1))
end

function wml_actions.prison_put_wooden_middlechamber_units(udArgs)
	local bFriendRight = helper.rand("true, false")
	local variable = udArgs.variable
	local tDwarves = helper.get_variable_array(variable)
	bFriendRight = false
	local function put_units(tFriendPos, tEnemyPos, sDirection, tDoorPos)
		for current_index, current_unit in ipairs(tDwarves) do
			if current_unit.race == "troll" then
				wesnoth.put_unit(tFriendPos[1], tFriendPos[2], current_unit)
				wesnoth.set_variable(string.format("%s[%u]", variable, current_index - 1))
				break
			end
		end

		local udFriend = wesnoth.get_units({ x = tFriendPos[1], y = tFriendPos[2] })[1]
		if udFriend then udFriend.side = 7
		else
			wesnoth.put_unit(tFriendPos[1], tFriendPos[2], { type = "Dwarvish Fighter", side = 7 })
		end

		for current_index, current_coords in ipairs(tEnemyPos) do
			wesnoth.put_unit(current_coords[1], current_coords[2], { type = helper.rand("Dwarvish Masked Lord,Dwarvish Masked Sentinel,Dwarvish Masked Dragonguard"), side = 3, upkeep = "loyal", random_traits = false, generate_name = false })
		end
		for current_index, current_coords in ipairs(tDoorPos) do
			wesnoth.get_units({ x = current_coords[1], y = current_coords[2] })[1].role = "wooden_floor_door"
		end
	end
	if bFriendRight then put_units( {29, 29}, { {16, 29}, {19, 28}, {22, 28} }, "sw", { {25, 30}, {26, 30}, {27, 31} } ) return end
	put_units({17, 29}, { {27, 27}, {29, 29}, {30, 30} }, "se", { {19, 31}, {20, 30}, {21, 30} })

end
