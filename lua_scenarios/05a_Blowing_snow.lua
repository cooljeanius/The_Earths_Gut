if not wml_actions then wml_actions = {} end

function wml_actions.blowing_snow_snowfall(udArgs)
	local sSnowless = udArgs.snowless
	local sSnowy = udArgs.snowy

	local tSnowlessLocs = wesnoth.get_locations({ terrain = sSnowless })

	local nTurnsLeft = math.max(1, udArgs.turn_limit - udArgs.turn_number + 1)
	local nNewSnowyLocs = math.floor( #tSnowlessLocs / nTurnsLeft )

	local sPattern = "[^%s,]+"
	for nCurrentNewSnowyLoc = 1, nNewSnowyLocs do
		local nRandomIndex = mathx.random_choice(string.format("1..%u", #tSnowlessLocs))
		local sTerrain = wesnoth.get_terrain(tSnowlessLocs[nRandomIndex][1], tSnowlessLocs[nRandomIndex][2])

		local sSnowlessCodeFunction, sSnowyCodeFunction = string.gmatch(sSnowless, sPattern), string.gmatch(sSnowy, sPattern)
		while true do
			local sSnowlessCode, sSnowyCode = sSnowlessCodeFunction(), sSnowyCodeFunction()
			if not sSnowlessCode then break end
			if sTerrain == sSnowlessCode then
				sTerrain = sSnowyCode
				break
			end
		end
		wesnoth.current.map[{tSnowlessLocs[nRandomIndex][1], tSnowlessLocs[nRandomIndex][2]}] = sTerrain
		table.remove(tSnowlessLocs, nRandomIndex)
	end
end
