local TopoRuntime = require(script.Parent.TopoRuntime)

local RecentErrors = {}
local RecentErrorLastTime = 0

export type SystemFunction = (...any) -> ()
export type SystemTable = {
	After: {System}?,
	Event: string?,
	Priority: number?,
	System: SystemFunction,
}

export type System = SystemFunction | SystemTable

local function SystemFunction(System: System)
	if type(System) == "table" then
		return (System :: SystemTable).System
	end

	return System
end

local function SystemName(System: System)
	local Function = SystemFunction(System)
	return debug.info(Function, "s") .. "->" .. debug.info(Function, "n")
end

local function SystemPriority(System: System)
	if type(System) == "table" then
		return (System :: SystemTable).Priority or 0
	end

	return 0
end

--[=[
	@class Loop

	The Loop class handles scheduling and *looping* (who would have guessed) over all of your game systems.

	:::caution Yielding
	Yielding is not allowed in systems. Doing so will result in the system thread being closed early, but it will not
	affect other systems.
	:::
]=]
local Loop = {}
Loop.ClassName = "Loop"
Loop.__index = Loop

--[=[
	Creates a new loop. `Loop.new` accepts as arguments the values that will be passed to all of your systems.

	So typically, you want to pass the World in here, as well as maybe a table of global game state.

	```lua
	local World = Matter.World.new()
	local GameState = {}

	local Loop = Matter.Loop.new(World, GameState)
	```

	@param ... ...any -- Values that will be passed to all of your systems
	@return Loop
]=]
function Loop.new(...)
	return setmetatable({
		Middlewares = {},
		OrderedSystemsByEvent = {},
		State = table.pack(...),
		Systems = {},
		SystemState = {},
	}, Loop)
end

local function SortFunction(A, B)
	local PriorityA = SystemPriority(A)
	local PriorityB = SystemPriority(B)

	if PriorityA == PriorityB then
		return SystemName(A) < SystemName(B)
	end

	return PriorityA < PriorityB
end

local function OrderSystemsByDependencies(UnscheduledSystems: {System})
	table.sort(UnscheduledSystems, SortFunction)

	local ScheduledSystemsSet = {}
	local ScheduledSystems = {}
	local Tombstone = {}

	while #ScheduledSystems < #UnscheduledSystems do
		local AtLeastOneScheduled = false

		local Index = 1
		local Priority
		while Index <= #UnscheduledSystems do
			local System = UnscheduledSystems[Index]

			-- If the system has already been scheduled it will have been replaced with this value
			if System == Tombstone then
				Index += 1
				continue
			end

			if Priority == nil then
				Priority = SystemPriority(System)
			elseif SystemPriority(System) ~= Priority then
				break
			end

			local AllScheduled = true

			if type(System) == "table" then
				local After = System.After
				if After then
					for _, Dependency in ipairs(After) do
						if ScheduledSystemsSet[Dependency] == nil then
							AllScheduled = false
							break
						end
					end
				end
			end

			if AllScheduled then
				AtLeastOneScheduled = true
				UnscheduledSystems[Index] = Tombstone :: System

				ScheduledSystemsSet[System] = System
				table.insert(ScheduledSystems, System)
			end

			Index += 1
		end

		if not AtLeastOneScheduled then
			error("Unable to schedule systems given current requirements")
		end
	end

	return ScheduledSystems
end

local function SortSystems(self)
	local SystemsByEvent = {}

	for System in pairs(self.Systems) do
		local EventName = "Default"

		if type(System) == "table" then
			local SystemEvent = System.Event
			if SystemEvent then
				EventName = SystemEvent
			end
		end

		local SystemsArray = SystemsByEvent[EventName]
		if not SystemsArray then
			SystemsArray = {}
			SystemsByEvent[EventName] = SystemsArray
		end

		table.insert(SystemsArray, System)
	end

	self.OrderedSystemsByEvent = {}

	for EventName, Systems in pairs(SystemsByEvent) do
		self.OrderedSystemsByEvent[EventName] = OrderSystemsByDependencies(Systems)
	end
end

--[=[
	@within Loop
	@type System SystemTable | (...any) -> ()

	Either a plain function or a table defining the system.
]=]

--[=[
	@within Loop
	@interface SystemTable
	.System (...any) -> () -- The system function
	.Event? string -- The event the system runs on. A string, a key from the table you pass to `Loop:Begin`.
	.Priority? number -- Priority influences the position in the frame the system is scheduled to run at.
	.After? {System} -- A list of systems that this system must run after.

	A table defining a system with possible options.

	Systems are scheduled in order of `Priority`, meaning lower `Priority` runs first.
	The default priority is `0`.
]=]

--[=[
	Schedules a set of systems based on the constraints they define.

	Systems may optionally declare:
	- The name of the event they run on (e.g., RenderStepped, Stepped, Heartbeat)
	- A numerical priority value
	- Other systems that they must run *after*

	If systems do not specify an event, they will run on the `Default` event.

	Systems that share an event will run in order of their priority, which means that systems with a lower `Priority`
	value run first. The default priority is `0`.

	Systems that have defined what systems they run `after` can only be scheduled after all systems they depend on have
	already been scheduled.

	All else being equal, the order in which systems run is stable, meaning if you don't change your code, your systems
	will always run in the same order across machines.

	:::info
	It is possible for your systems to be in an unresolvable state. In which case, `ScheduleSystems` will error.
	This can happen when your systems have circular or unresolvable dependency chains.

	If a system has both a `Priority` and defines systems it runs `After`, the system can only be scheduled if all of
	the systems it depends on have a lower or equal priority.

	Systems can never depend on systems that run on other events, because it is not guaranteed or required that events
	will fire every frame or will always fire in the same order.
	:::

	:::caution
	`ScheduleSystems` has to perform nontrivial sorting work each time it's called, so you should avoid calling it multiple
	times if possible.
	:::

	@param Systems { System } -- Array of systems to schedule.
]=]
function Loop:ScheduleSystems(Systems: {System})
	for _, System in ipairs(Systems) do
		self.Systems[System] = System
		self.SystemState[System] = {}
	end

	SortSystems(self)
end

function Loop:ScheduleSystem(System: System)
	return self:ScheduleSystems(table.create(1, System))
end

--[=[
	Connects to frame events and starts invoking your systems.

	Pass a table of events you want to be able to run systems on, a map of name to event. Systems can use these names
	to define what event they run on. By default, systems run on an event named `"default"`. Custom events may be used
	if they have a `Connect` function.

	```lua
	Loop:Begin({
		Default = RunService.Heartbeat;
		Heartbeat = RunService.Heartbeat;
		RenderStepped = RunService.RenderStepped;
		Stepped = RunService.Stepped;
	})
	```

	&nbsp;

	:::info
	Events that do not have any systems scheduled to run on them **at the time you call `Loop:begin`** will be skipped
	and never connected to. All systems should be scheduled before you call this function.
	:::

	Returns a table similar to the one you passed in, but the values are `RBXScriptConnection` values (or whatever is
	returned by `:Connect` if you passed in a synthetic event).

	@param Events {[string]: RBXScriptSignalLike} -- A map from event name to event objects.
	@return {[string]: RBXScriptConnectionLike} -- A map from your event names to connection objects.
]=]
function Loop:Begin(Events)
	local Connections = {}

	local State = self.State
	local Middlewares = self.Middlewares
	local OrderedSystemsByEvent = self.OrderedSystemsByEvent
	local SystemState = self.SystemState

	for EventName, Event in pairs(Events) do
		if not OrderedSystemsByEvent[EventName] then
			-- Skip events that have no systems
			continue
		end

		local LastTime = os.clock()
		local Generation = false

		local function StepSystems()
			local CurrentTime = os.clock()
			local DeltaTime = CurrentTime - LastTime
			LastTime = CurrentTime

			Generation = not Generation

			for _, System in ipairs(OrderedSystemsByEvent[EventName]) do
				TopoRuntime.Start({
					Frame = {
						DeltaTime = DeltaTime,
						Generation = Generation,
					},

					System = SystemState[System],
				}, function()
					local Function = SystemFunction(System)
					debug.profilebegin("system: " .. SystemName(System))

					local Thread = coroutine.create(Function)
					local Success, ErrorValue = coroutine.resume(Thread, table.unpack(State, 1, State.n))

					if coroutine.status(Thread) ~= "dead" then
						coroutine.close(Thread)

						task.spawn(
							error,
							string.format(
								"Matter: System %s yielded! Its thread has been closed. "
									.. "Yielding in systems is not allowed.",
								SystemName(System)
							)
						)
					end

					if not Success then
						if os.clock() - RecentErrorLastTime > 10 then
							RecentErrorLastTime = os.clock()
							RecentErrors = {}
						end

						local ErrorString = SystemName(System) .. ": " .. tostring(ErrorValue)
						if not RecentErrors[ErrorString] then
							task.spawn(error, ErrorString)
							warn("Matter: The above error will be suppressed for the next 10 seconds")
							RecentErrors[ErrorString] = true
						end
					end

					debug.profileend()
				end)
			end
		end

		for _, Middleware in ipairs(Middlewares) do
			StepSystems = Middleware(StepSystems)

			if type(StepSystems) ~= "function" then
				error(
					string.format(
						"Middleware function %s:%s returned %s instead of a function",
						debug.info(Middleware, "s"),
						debug.info(Middleware, "l"),
						typeof(StepSystems)
					)
				)
			end
		end

		Connections[EventName] = Event:Connect(StepSystems)
	end

	return Connections
end

--[=[
	Adds a user-defined middleware function that is called during each frame.

	This allows you to run code before and after each frame, to perform initialization and cleanup work.

	```lua
	Loop:AddMiddleware(function(NextFunction)
		return function()
			Plasma.start(PlasmaNode, NextFunction)
		end
	end)
	```

	You must pass `AddMiddleware` a function that itself returns a function that invokes `NextFunction` at some point.

	The outer function is invoked only once. The inner function is invoked during each frame event.

	:::info
	Middleware added later "wraps" middleware that was added earlier. The innermost middleware function is the internal
	function that actually calls your systems.
	:::
	@param Middleware (NextFunction: () -> ()) -> () -> ()
	@return Loop -- Returns self, used for chaining.
]=]
function Loop:AddMiddleware(Middleware: (NextFunction: () -> ()) -> () -> ())
	table.insert(self.Middlewares, Middleware)
	return self
end

function Loop:__tostring()
	return "Loop"
end

export type Loop = typeof(Loop.new(1))

Loop.addMiddleware = Loop.AddMiddleware
Loop.begin = Loop.Begin
Loop.scheduleSystem = Loop.ScheduleSystem
Loop.scheduleSystems = Loop.ScheduleSystems

table.freeze(Loop)
return Loop
