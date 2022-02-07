local MergeSelect = require(script.MergeSelect)
local MergeTable = require(script.MergeTable)
local None = require(script.None)

type Function = typeof(MergeSelect)

type Profiler = {
	Begin: (Name: string) -> (),
	End: () -> (),
}

local RUN = 10
local SIZE = 1000

local function CreateFunction(Function: Function)
	return function(_Profiler: Profiler, BaseTable, JoinWith)
		for _ = 1, RUN do
			Function(BaseTable, JoinWith)
		end
	end
end

local function GenerateTable(Size: number)
	local Table = {}
	for Index = 1, Size do
		Table[tostring(Index)] = math.random(10) == 1 and None or Index
	end

	return Table
end

return {
	ParameterGenerator = function()
		return GenerateTable(SIZE), GenerateTable(math.floor(SIZE / 2))
	end,

	Functions = {
		["Merge (table)"] = CreateFunction(MergeTable),
		["Merge (select)"] = CreateFunction(MergeSelect),
	},
}
