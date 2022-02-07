local None = require(script.Parent.None)
type GenericTable = {[any]: any}

local function Merge(...: GenericTable)
	local New = {}
	for Index = 1, select("#", ...) do
		local Dictionary = select(Index, ...)
		if Dictionary then
			if type(Dictionary) ~= "table" then
				error(string.format("table expected, got %s", typeof(Dictionary)), 2)
			end

			for Key, Value in pairs(Dictionary) do
				if Value == None then
					New[Key] = nil
				else
					New[Key] = Value
				end
			end
		end
	end

	return New
end

return Merge
