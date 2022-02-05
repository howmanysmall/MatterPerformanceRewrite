local TopoRuntime = {}
local Stack = {}
local Length = 0

local function NewStackFrame(Node)
	return {
		AccessedKeys = {},
		Node = Node,
	}
end

local function Cleanup()
	local CurrentFrame = Stack[Length]
	local AccessedKeys = CurrentFrame.AccessedKeys

	for BaseKey, State in pairs(CurrentFrame.Node.System) do
		local Storage = State.Storage
		for Key, Value in pairs(Storage) do
			local AccessedValue = AccessedKeys[BaseKey]
			if not AccessedValue or not AccessedValue[Key] then
				local CleanupFunction = State.CleanupFunction

				if CleanupFunction then
					local ShouldAbortCleanup = CleanupFunction(Value)
					if ShouldAbortCleanup then
						continue
					end
				end

				Storage[Key] = nil
			end
		end
	end
end

function TopoRuntime.Start(Node, Function)
	Length += 1
	Stack[Length] = NewStackFrame(Node)
	Function()
	Cleanup()

	Stack[Length] = nil
	Length -= 1
end

function TopoRuntime.UseFrameState()
	return Stack[Length].Node.Frame
end

--[=[
	@within Matter

	:::tip
	**Don't use this function directly in your systems.**

	This function is used for implementing your own topologically-aware functions. It should not be used in your
	systems directly. You should use this function to implement your own utilities, similar to `UseEvent` and
	`UseThrottle`.
	:::

	`UseHookState` does one thing: it returns a table. An empty, pristine table. Here's the cool thing though:
	it always returns the *same* table, based on the script and line where *your function* (the function calling
	`UseHookState`) was called.

	### Uniqueness

	If your function is called multiple times from the same line, perhaps within a loop, the default behavior of
	`UseHookState` is to uniquely identify these by call count, and will return a unique table for each call.

	However, you can override this behavior: you can choose to key by any other value. This means that in addition to
	script and line number, the storage will also only return the same table if the unique value (otherwise known as the
	"discriminator") is the same.

	### Cleaning up
	As a second optional parameter, you can pass a function that is automatically invoked when your storage is about
	to be cleaned up. This happens when your function (and by extension, `UseHookState`) ceases to be called again
	next frame (keyed by script, line number, and discriminator).

	Your cleanup callback is passed the storage table that's about to be cleaned up. You can then perform cleanup work,
	like disconnecting events.

	*Or*, you could return `true`, and abort cleaning up altogether. If you abort cleanup, your storage will stick
	around another frame (even if your function wasn't called again). This can be used when you know that the user will
	(or might) eventually call your function again, even if they didn't this frame. (For example, caching a value for
	a number of seconds).

	If cleanup is aborted, your cleanup function will continue to be called every frame, until you don't abort cleanup,
	or the user actually calls your function again.

	### Example: UseThrottle

	This is the entire implementation of the built-in `UseThrottle` function:

	```lua
	local function Cleanup(Storage)
		return os.clock() < Storage.Expiry
	end

	local function UseThrottle(Seconds, Discriminator)
		local Storage = UseHookState(Discriminator, Cleanup)

		if Storage.Time == nil or os.clock() - Storage.Time >= Seconds then
			Storage.Time = os.clock()
			Storage.Expiry = os.clock() + Seconds
			return true
		end

		return false
	end
	```

	A lot of talk for something so simple, right?

	@param Discriminator? any -- A unique value to additionally key by
	@param CleanupFunction (Storage: {}) -> boolean? -- A function to run when the storage for this hook is cleaned up
]=]
function TopoRuntime.UseHookState(Discriminator, CleanupFunction): {}
	local File, Line = debug.info(3, "sl")
	local Function = debug.info(2, "f")

	local BaseKey = string.format("%s:%s:%d", tostring(Function), File, Line)

	local CurrentFrame = Stack[Length]
	local AccessedKeys = CurrentFrame.AccessedKeys
	local AccessedValues = AccessedKeys[BaseKey]

	if not AccessedValues then
		AccessedValues = {}
		AccessedKeys[BaseKey] = AccessedValues
	end

	local Key = #AccessedValues
	if Discriminator ~= nil then
		if type(Discriminator) == "number" then
			Discriminator = tostring(Discriminator)
		end

		Key = Discriminator
	end

	AccessedValues[Key] = true
	local System = CurrentFrame.Node.System
	local SystemData = System[BaseKey]

	if not SystemData then
		SystemData = {
			CleanupFunction = CleanupFunction,
			Storage = {},
		}

		System[BaseKey] = SystemData
	end

	local Storage = SystemData.Storage
	local StorageData = Storage[Key]
	if not StorageData then
		StorageData = {}
		Storage[Key] = StorageData
	end

	return StorageData
end

-- Compat
TopoRuntime.start = TopoRuntime.Start
TopoRuntime.useFrameState = TopoRuntime.UseFrameState
TopoRuntime.useHookState = TopoRuntime.UseHookState

table.freeze(TopoRuntime)
return TopoRuntime
