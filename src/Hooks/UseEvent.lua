local Queue = require(script.Parent.Parent.Queue)
local TopoRuntime = require(script.Parent.Parent.TopoRuntime)

local function Cleanup(Storage)
	Storage.Connection:Disconnect()
	Storage.Queue = nil
end

--[=[
	@within Matter

	:::info Topologically-aware function
	This function is only usable if called within the context of [`Loop:Begin`](/api/Loop#Begin).
	:::

	Collects events that fire during the frame and allows iteration over event arguments.

	```lua
	for _, Player in ipairs(Players:GetPlayers()) do
		for _, Character in UseEvent(Player, "CharacterAdded") do
			World:Spawn(
				Components.Target(),
				Components.Model({
					Model = Character;
				})
			)
		end
	end
	```

	Returns an iterator function that returns an ever-increasing number, starting at 1, followed by any event arguments
	from the specified event.

	Events are returned in the order that they were fired.

	:::caution
	`useEvent` keys storage uniquely identified by **the script and line number** `useEvent` was called from, and the
	first parameter (instance). If the second parameter, `event`, is not equal to the event passed in for this unique
	storage last frame, the old event is disconnected from and the new one is connected in its place.

	Tl;dr: on a given line, you should hard-code a single event to connect to. Do not dynamically change the event with
	a variable. Dynamically changing the first parameter (instance) is fine.

	```lua
	for _, BasePart in next, SomeTable do
		for Index, ArgumentA, ArgumentB in UseEvent(BasePart, "Touched") do -- This is ok
		end
	end

	for _, BasePart in next, SomeTable do
		local Event = GetEventSomehow()
		for Index, ArgumentA, ArgumentB in UseEvent(BasePart, Event) do -- PANIC! This is NOT OK
		end
	end
	```
	:::

	If `useEvent` ceases to be called on the same line with the same instance and event, the event connection is
	disconnected from automatically.

	You can also pass the actual event object instead of its name as the second parameter:

	```lua
	UseEvent(BasePart, BasePart.Touched)
	UseEvent(Object, Object:GetPropertyChangedSignal("Name"))
	```

	@param Object Instance -- The instance that has the event you want to connect to
	@param Event string | RBXScriptSignal -- The name of or actual event that you want to connect to
]=]
local function UseEvent(Object: Instance, Event: string | RBXScriptSignal): () -> (number, ...any)
	if Object == nil then
		error("Instance is nil", 2)
	end

	if Event == nil then
		error("Event is nil", 2)
	end

	local Storage = TopoRuntime.UseHookState(Object, Cleanup)
	local LocalEvent: RBXScriptSignal = if type(Event) == "string"
		then (Object :: any)[Event] :: RBXScriptSignal
		else Event :: RBXScriptSignal

	if Storage.Event ~= LocalEvent then
		local StorageCleanup = Storage.Cleanup
		if StorageCleanup then
			StorageCleanup()
			table.clear(Storage)
		end

		local StorageQueue = Queue.new()
		Storage.Queue = StorageQueue
		Storage.Event = LocalEvent
		Storage.Connection = LocalEvent:Connect(function(...)
			StorageQueue:Push(table.pack(...))
		end)
	end

	local Index = 0
	return function()
		Index += 1
		local Arguments = Storage.Queue:Pop()
		if Arguments then
			return Index, table.unpack(Arguments, 1, Arguments.n)
		end
	end
end

return UseEvent
