local TopoRuntime = require(script.Parent.Parent.TopoRuntime)

local function Cleanup(Storage)
	return os.clock() < Storage.Expiry
end

--[=[
	@within Matter

	:::info Topologically-aware function
	This function is only usable if called within the context of [`Loop:Begin`](/api/Loop#Begin).
	:::

	Utility for easy time-based throttling.

	Accepts a duration, and returns `true` if it has been that long since the last time this function returned `true`.
	Always returns `true` the first time.

	This function returns unique results keyed by script and line number. Additionally, uniqueness can be keyed by a
	unique value, which is passed as a second parameter. This is useful when iterating over a query result, as you can
	throttle doing something to each entity individually.

	```lua
	if UseThrottle(1) then -- Keyed by script and line number only
		print("only prints every second")
	end

	for Id, Enemy in World:Query(Components.Enemy) do
		if UseThrottle(5, Id) then -- Keyed by script, line number, and the entity id
			print("Recalculate target...")
		end
	end
	```

	@param Seconds number -- The number of seconds to throttle for
	@param Discriminator? any -- A unique value to additionally key by
	@return boolean -- returns true every x seconds, otherwise false
]=]
local function UseThrottle(Seconds: number, Discriminator: any?)
	local Storage = TopoRuntime.UseHookState(Discriminator, Cleanup)
	local Time = Storage.Time

	if Time == nil or os.clock() - Time >= Seconds then
		Storage.Time = os.clock()
		Storage.Expiry = os.clock() + Seconds
		return true
	end

	return false
end

return UseThrottle
