local None = newproxy(true)
local Metatable = getmetatable(None)

function Metatable:__tostring()
	return "Matter.None"
end

return None
