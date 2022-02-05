local TopoRuntime = require(script.Parent.Parent.TopoRuntime)

--[=[
	@within Matter

	:::info Topologically-aware function
	This function is only usable if called within the context of [`Loop:Begin`](/api/Loop#Begin).
	:::

	Returns the `TimeFunction()` time delta between the start of this and last frame.
	@return number
]=]
local function UseDeltaTime(): number
	return TopoRuntime.UseFrameState().DeltaTime
end

return UseDeltaTime
