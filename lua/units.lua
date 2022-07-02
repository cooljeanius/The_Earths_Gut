local units = {}

	function units.main()
	end

------------------------------------------------------------------------------------------------------------------------

	function units.sort_units_array(udArgs)
		local sUnits = udArgs.variable
		local wtUnits = wml.array_access.get(sUnits)

		local function is_more_experienced(wtSecondUnit, wtFirstUnit)
			--helper function for sorting a units array
			--first and second unit are reversed to achieve sorting in descending order
			--return true if wtSecondUnit is more experienced than wtFirstUnit
			local nFirstLevel = wtFirstUnit.level
			local nSecondLevel = wtSecondUnit.level

			if nFirstLevel == nSecondLevel  then
				--Take the experience acquired - that unit is more likely to be the one that the player wants to level.
				return wtFirstUnit.experience < wtSecondUnit.experience
			end
			return nFirstLevel < nSecondLevel
		end

		table.sort(wtUnits, is_more_experienced)

		wml.array_access.set(sUnits, wtUnits)
	end

return units
