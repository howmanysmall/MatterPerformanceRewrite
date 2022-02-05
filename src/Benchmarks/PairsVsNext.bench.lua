local RUN = 10000
type Profiler = {
	Begin: (Name: string) -> (),
	End: () -> (),
}

-- About equal, so I'll change it to pairs for now.

return {
	ParameterGenerator = function()
		local Dictionary = {}
		for Index = 1, RUN do
			Dictionary[tostring(Index)] = Index
		end

		return Dictionary
	end,

	Functions = {
		["pairs"] = function(_, Dictionary)
			local New = {}
			for Key, Value in pairs(Dictionary) do
				New[Key] = Value
			end

			table.clear(New)
		end,

		["next"] = function(_, Dictionary)
			local New = {}
			for Key, Value in next, Dictionary do
				New[Key] = Value
			end

			table.clear(New)
		end,
	},
}
